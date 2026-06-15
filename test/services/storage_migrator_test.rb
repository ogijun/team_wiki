require "test_helper"

class StorageMigratorTest < ActiveSupport::TestCase
  # 認証情報なしで service 間コピーを検証するため、Disk(test) → Disk(test_secondary) で回す。
  FROM = "test".freeze
  TO = "test_secondary".freeze

  def source
    ActiveStorage::Blob.services.fetch(FROM)
  end

  def target
    ActiveStorage::Blob.services.fetch(TO)
  end

  def create_blob(content, filename: "a.txt")
    ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new(content), filename: filename,
      content_type: "text/plain", service_name: FROM
    )
  end

  teardown do
    # 並列テストワーカーは tmp/storage_secondary を共有するため、ディレクトリごと rm_rf すると
    # 他ワーカーのファイルを巻き込んで flaky になる。自分の DB に見えている blob（=このワーカーが
    # 作ったもの。キーはランダムで衝突しない）のキーだけを両 service から消す。
    ActiveStorage::Blob.find_each do |blob|
      [ source, target ].each { |svc| svc.delete(blob.key) }
    end
  end

  test "copies blob content to the target service and updates service_name" do
    blob = create_blob("hello world")

    result = StorageMigrator.call(from: FROM, to: TO)

    assert target.exist?(blob.key)
    assert_equal "hello world", target.download(blob.key)
    assert_equal TO, blob.reload.service_name
    assert_equal 1, result[:migrated]
    assert_equal 0, result[:skipped]
    assert_empty result[:failed]
  end

  test "does not delete the source file (rollback safety)" do
    blob = create_blob("keep me")

    StorageMigrator.call(from: FROM, to: TO)

    assert source.exist?(blob.key), "source file must remain for rollback"
    assert_equal "keep me", source.download(blob.key)
  end

  test "is idempotent: a second run skips and changes nothing" do
    blob = create_blob("once")
    StorageMigrator.call(from: FROM, to: TO)
    content_after_first = target.download(blob.key)

    # 1回目で service_name が TO になり from には残らない＝再実行は空走。
    # 既に target にあるキーを再び from 側に置いて、skip されること（実体不変）を確かめる。
    blob.update_column(:service_name, FROM)
    result = StorageMigrator.call(from: FROM, to: TO)

    assert_equal 1, result[:skipped]
    assert_equal 0, result[:migrated]
    assert_empty result[:failed]
    assert_equal content_after_first, target.download(blob.key), "content must be untouched"
    # skip 経路では service_name を触らない（既に target にあるので移行不要）。
    assert_equal FROM, blob.reload.service_name
  end

  test "raises ArgumentError for an unknown source service" do
    error = assert_raises(ArgumentError) { StorageMigrator.call(from: "nope", to: TO) }
    assert_match(/nope/, error.message)
  end

  test "raises ArgumentError for an unknown target service" do
    assert_raises(ArgumentError) { StorageMigrator.call(from: FROM, to: "nope") }
  end

  test "raises ArgumentError when from equals to" do
    error = assert_raises(ArgumentError) { StorageMigrator.call(from: FROM, to: FROM) }
    assert_match(/同一|same|#{FROM}/, error.message)
  end

  # libvips で実画像を生成（fixture の example-photo.png はスタブで decode できないため）。
  def valid_png
    StringIO.new(Vips::Image.black(8, 8).write_to_buffer(".png"))
  end

  test "migrates variant image blobs as plain blobs (Rails 8 tracks variants as blob rows)" do
    original = ActiveStorage::Blob.create_and_upload!(
      io: valid_png, filename: "p.png", content_type: "image/png", service_name: FROM
    )
    # 追跡バリアントは VariantRecord の image 添付として別の Blob 行になる。
    variant_blob = original.variant(resize_to_limit: [ 16, 16 ]).processed.image.blob
    assert_not_equal original.id, variant_blob.id
    assert_equal FROM, variant_blob.service_name

    StorageMigrator.call(from: FROM, to: TO)

    # オリジナルとバリアントの両方が素朴な blob 走査で移行される。
    assert target.exist?(original.key)
    assert target.exist?(variant_blob.key)
    assert_equal TO, original.reload.service_name
    assert_equal TO, variant_blob.reload.service_name
  end

  test "a blob whose source file is missing is recorded as failed without aborting others" do
    missing = create_blob("gone")
    source.delete(missing.key) # 実体だけ消して DB 行は残す
    ok = create_blob("present", filename: "b.txt")

    result = StorageMigrator.call(from: FROM, to: TO)

    # 健全なブロブは移行される
    assert target.exist?(ok.key)
    assert_equal TO, ok.reload.service_name
    assert_equal 1, result[:migrated]

    # 実体欠損のブロブは failed に入り、service_name は据え置き
    assert_equal 1, result[:failed].size
    failed = result[:failed].first
    assert_equal missing.id, failed[:blob_id]
    assert_equal missing.key, failed[:key]
    assert_predicate failed[:error], :present?
    assert_equal FROM, missing.reload.service_name
    assert_not target.exist?(missing.key)
  end
end
