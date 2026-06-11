# Active Storage の blob 実体を、ある service から別の service へコピーする移行コマンド。
# 冪等（再実行で既存キーは skip）・チェックサム検証つき・blob 単位でエラー隔離。
#
# 対象は ActiveStorage::Blob.where(service_name: from) の全行。Rails 8 では追跡バリアントも
# VariantRecord の image 添付として独立した Blob 行を持つため、この素朴な blob 走査だけで
# オリジナルとバリアント画像の両方を移行できる（schema の active_storage_variant_records は
# blob_id 参照のみ）。
#
# 実体はコピーするだけで元 service からは削除しない（ロールバック安全性）。切り戻しは
# ACTIVE_STORAGE_SERVICE を戻すだけで済む。
module StorageMigrator
  module_function

  LOG_EVERY = 50

  def call(from:, to:, logger: Rails.logger)
    from = from.to_s
    to = to.to_s
    from_service = fetch_service(from)
    to_service = fetch_service(to)
    raise ArgumentError, "from と to が同一の service です: #{from}" if from == to

    migrated = 0
    skipped = 0
    failed = []
    seen = 0

    ActiveStorage::Blob.where(service_name: from).find_each do |blob|
      seen += 1
      if to_service.exist?(blob.key)
        skipped += 1
      else
        # blob.open は from_service から実体を読む（service_name はまだ from）。
        # checksum を渡すことで Disk は IntegrityError、S3 は content-md5 で完全性を検証する。
        blob.open { |file| to_service.upload(blob.key, file, checksum: blob.checksum) }
        blob.update_column(:service_name, to)
        migrated += 1
      end
      logger&.info("[StorageMigrator] #{seen} 件処理 (migrated=#{migrated} skipped=#{skipped} failed=#{failed.size})") if (seen % LOG_EVERY).zero?
    rescue StandardError => e
      # 1件の失敗で全体を止めない。service_name は更新済みでないので from のまま残る。
      failed << { blob_id: blob.id, key: blob.key, error: e.message }
      logger&.error("[StorageMigrator] blob ##{blob.id} (#{blob.key}) の移行に失敗: #{e.class}: #{e.message}")
    end

    logger&.info("[StorageMigrator] 完了: migrated=#{migrated} skipped=#{skipped} failed=#{failed.size}")
    { migrated: migrated, skipped: skipped, failed: failed }
  end

  def fetch_service(name)
    ActiveStorage::Blob.services.fetch(name) do
      raise ArgumentError, "未知の service です: #{name}（config/storage.yml を確認してください）"
    end
  end
end
