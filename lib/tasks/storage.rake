namespace :storage do
  desc "Active Storage の blob を service 間で移行する (FROM=local TO=r2)。冪等・チェックサム検証つき"
  task migrate: :environment do
    from = ENV.fetch("FROM", "local")
    to = ENV.fetch("TO", "r2")

    puts "[storage:migrate] #{from} → #{to} を開始します"
    result = StorageMigrator.call(from: from, to: to)

    puts "[storage:migrate] 完了: migrated=#{result[:migrated]} skipped=#{result[:skipped]} failed=#{result[:failed].size}"
    result[:failed].each do |f|
      puts "  失敗 blob ##{f[:blob_id]} (#{f[:key]}): #{f[:error]}"
    end

    abort("[storage:migrate] #{result[:failed].size} 件の移行に失敗しました") if result[:failed].any?
  end
end
