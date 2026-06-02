class RegenerateArticleSlugs < ActiveRecord::Migration[8.1]
  # 既存の title 由来 slug を、新方式のランダムトークンへ振り直す（冪等ではない・一度きり）。
  def up
    Article.reset_column_information
    Article.find_each do |article|
      article.update_column(:slug, unique_token)
    end
  end

  def down
    # 旧 slug は復元不能（title 由来へ戻す意味もないため何もしない）。
  end

  private

  def unique_token
    loop do
      candidate = Slug.token
      break candidate unless Article.exists?(slug: candidate)
    end
  end
end
