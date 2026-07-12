class CreatePublications < ActiveRecord::Migration[8.1]
  def change
    create_table :publications do |t|
      t.string :title, null: false
      t.string :kind, null: false
      t.datetime :released_at
      t.string :released_precision
      t.string :sales_status, null: false, default: "on_sale"
      t.string :store_url
      t.references :registered_by, null: false, foreign_key: { to_table: :users }
      t.timestamps
    end
    add_index :publications, :released_at
  end
end
