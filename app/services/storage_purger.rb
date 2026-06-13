# 移行が済んだ後、旧 service（例: local Disk）に残った blob の実体を安全に削除する。
# StorageMigrator の対。R2 移行後の VPS ボリューム掃除を、手作業の rm（DB ファイル巻き込み事故）
# を避けて専用プログラムで行うためのもの。冪等。
#
# 二段の安全装置:
#   1) 現役の既定 service（ACTIVE_STORAGE_SERVICE）は削除対象にできない（誤実行を弾く）。
#   2) service_name が from の blob は「まだ from で配信中」なので触らない（where.not で除外）。
#      = from に残るコピーが本当に不要なものだけを消す。
module StoragePurger
  module_function

  def call(from:, logger: Rails.logger)
    from = from.to_s
    service = ActiveStorage::Blob.services.fetch(from) do
      raise ArgumentError, "未知の service です: #{from}（config/storage.yml を確認してください）"
    end
    current = ActiveStorage::Blob.service.name.to_s
    raise ArgumentError, "現役の既定 service (#{from}) は purge できません" if from == current

    purged = 0
    missing = 0
    # from では配信していない blob（=移行済み）の、from に残る実体だけを消す
    ActiveStorage::Blob.where.not(service_name: from).find_each do |blob|
      if service.exist?(blob.key)
        service.delete(blob.key)
        purged += 1
      else
        missing += 1
      end
    rescue StandardError => e
      logger&.error("[StoragePurger] blob ##{blob.id} (#{blob.key}) の削除に失敗: #{e.class}: #{e.message}")
    end

    logger&.info("[StoragePurger] 完了: from=#{from} purged=#{purged} missing=#{missing}")
    { purged: purged, missing: missing }
  end
end
