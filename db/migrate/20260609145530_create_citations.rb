class CreateCitations < ActiveRecord::Migration[8.1]
  def change
    create_table :citations do |t|
      t.references :article, null: false, foreign_key: true
      # 本文の [[ref:handle]] を解決した資料。資料削除や未解決(typo)では null。
      t.references :material, null: true, foreign_key: true
      t.string :material_handle, null: false
      t.timestamps
    end
    add_index :citations, [ :article_id, :material_handle ], unique: true
  end
end
