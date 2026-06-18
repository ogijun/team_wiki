namespace :articles do
  desc "資料から自動生成され手付かずのスタブ記事を削除（一度きり）。DRY_RUN=1 で件数のみ。"
  task cleanup_untouched_auto_stubs: :environment do
    targets = Article.untouched_auto_stubs
    puts "対象: #{targets.size} 件（手付かず自動スタブ）"
    if ENV["DRY_RUN"] == "1"
      puts "DRY_RUN: 削除しません。"
    else
      deleted = 0
      Article.transaction { targets.each { |a| a.destroy!; deleted += 1 } }
      puts "削除しました: #{deleted} 件"
    end
  end
end
