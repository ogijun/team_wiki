class CreateStatSnapshots < ActiveRecord::Migration[8.1]
  def change
    create_table :stat_snapshots do |t|
      t.date :date, null: false, index: { unique: true }
      t.integer :articles_count, null: false, default: 0
      t.integer :materials_count, null: false, default: 0
      t.integer :unconfirmed_materials_count, null: false, default: 0
      t.integer :transcribed_chars, null: false, default: 0
      t.timestamps
    end
  end
end
