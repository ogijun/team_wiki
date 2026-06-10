class AddSortIndexes < ActiveRecord::Migration[8.1]
  def change
    # よく使う並び順のための index：記事一覧/ホームは updated_at 降順、資料一覧は発行日ソート可。
    add_index :articles, :updated_at
    add_index :materials, :published_at
  end
end
