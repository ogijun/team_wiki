namespace :materials do
  desc "既存 PDF の page_count を抽出して埋める（冪等）"
  task backfill_page_count: :environment do
    n = Material.backfill_page_counts!
    puts "page_count を #{n} 件の PDF 資料に補完しました。"
  end
end
