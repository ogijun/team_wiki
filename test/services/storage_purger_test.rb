require "test_helper"

class StoragePurgerTest < ActiveSupport::TestCase
  # テスト環境の既定 service は "test"。これを「移行先の現役 service（=本番の r2 相当）」とし、
  # purge 対象の旧 service を "test_secondary"（=本番の local 相当）とする。
  OLD = "test_secondary".freeze   # purge する側（移行元）
  CURRENT = "test".freeze         # 現役の既定 service（移行先）

  def old_service = ActiveStorage::Blob.services.fetch(OLD)
  def current_service = ActiveStorage::Blob.services.fetch(CURRENT)

  # OLD に作って CURRENT へ移行済み（service_name=CURRENT、実体は両方）の blob を用意する。
  def migrated_blob(content = "x")
    blob = ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new(content), filename: "a.txt", content_type: "text/plain", service_name: OLD
    )
    blob.open { |f| current_service.upload(blob.key, f, checksum: blob.checksum) }
    blob.update_column(:service_name, CURRENT)
    blob
  end

  teardown do
    ActiveStorage::Blob.find_each { |b| [ old_service, current_service ].each { |svc| svc.delete(b.key) } }
  end

  test "deletes the old-service copy of migrated blobs, keeps the current copy and the DB row" do
    blob = migrated_blob("hello")
    result = StoragePurger.call(from: OLD)

    assert_equal 1, result[:purged]
    assert_not old_service.exist?(blob.key), "旧 service の実体は削除される"
    assert current_service.exist?(blob.key), "現役 service の実体は残る"
    assert ActiveStorage::Blob.exists?(blob.id), "DB 行は残る"
    assert_equal CURRENT, blob.reload.service_name
  end

  test "is idempotent — a second run reports the source already absent" do
    migrated_blob
    StoragePurger.call(from: OLD)
    result = StoragePurger.call(from: OLD)
    assert_equal 0, result[:purged]
    assert_equal 1, result[:missing]
  end

  test "protects a blob still served from the purged service (service_name == from)" do
    # service_name が OLD のまま＝まだ OLD で配信中 → where.not で除外され触らない
    live = ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new("live"), filename: "b.txt", content_type: "text/plain", service_name: OLD
    )
    result = StoragePurger.call(from: OLD)
    assert old_service.exist?(live.key), "OLD で配信中の blob の実体は保護される"
    assert_equal 0, result[:purged]
  end

  test "refuses to purge the current default service (guards a fat-finger)" do
    error = assert_raises(ArgumentError) { StoragePurger.call(from: CURRENT) }
    assert_match(/現役/, error.message)
  end

  test "unknown service name raises" do
    assert_raises(ArgumentError) { StoragePurger.call(from: "nope") }
  end
end
