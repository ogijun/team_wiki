class CreateTranscriptions < ActiveRecord::Migration[8.1]
  def change
    create_table :transcriptions do |t|
      t.references :material, null: false, foreign_key: true, index: { unique: true }
      t.references :author, null: false, foreign_key: { to_table: :users }
      t.text :body
      t.string :status, null: false, default: "drafting"
      t.timestamps
    end
  end
end
