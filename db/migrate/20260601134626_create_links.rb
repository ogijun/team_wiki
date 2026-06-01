class CreateLinks < ActiveRecord::Migration[8.1]
  def change
    create_table :links do |t|
      t.references :source_page, null: false, foreign_key: { to_table: :pages }
      t.string :target_title, null: false
      t.integer :target_page_id

      t.timestamps
    end
    add_index :links, [:source_page_id, :target_title], unique: true
    add_index :links, :target_page_id
    add_index :links, :target_title
  end
end
