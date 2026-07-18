class CreateNotifications < ActiveRecord::Migration[8.1]
  def change
    create_table :notifications do |t|
      t.references :recipient, null: false, foreign_key: { to_table: :users }
      t.references :actor, null: false, foreign_key: { to_table: :users }
      t.string :kind, null: false
      t.references :subject, polymorphic: true, null: false
      t.timestamps
    end
    add_index :notifications, %i[recipient_id created_at]

    add_column :users, :notifications_seen_at, :datetime
  end
end
