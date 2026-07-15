class AddLockVersionToArticles < ActiveRecord::Migration[8.1]
  # 記事の同時編集による lost update を防ぐ楽観ロック用カラム。
  # Rails は "lock_version" 列を自動検出し、save 時に version 比較 → 競合で StaleObjectError。
  def change
    add_column :articles, :lock_version, :integer, default: 0, null: false
  end
end
