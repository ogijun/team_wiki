class CreateRevisions < ActiveRecord::Migration[8.1]
  def change
    create_table :revisions do |t|
      t.references :page, null: false, foreign_key: true
      t.references :author, null: false, foreign_key: { to_table: :users }
      t.text :body, null: false, default: ""
      t.string :edit_summary

      t.timestamps
    end
  end
end
