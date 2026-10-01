namespace :search do
  desc "全文検索の索引を全件作り直す（冪等。初回投入とタグ改名後の同期に使う）"
  task rebuild: :environment do
    $stdout.sync = true
    puts "索引を作り直します（現在 #{SearchIndexer.count} 行）"
    count = SearchIndexer.rebuild!
    puts "#{count} 行を投入しました。"
  end
end
