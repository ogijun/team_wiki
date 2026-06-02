class CreateActivities < ActiveRecord::Migration[8.1]
  def change
    create_table :activities do |t|
      t.references :user, null: false, foreign_key: true
      t.string :action, null: false
      t.references :subject, polymorphic: true, null: true
      t.string :subject_label
      t.timestamps
    end
    add_index :activities, :created_at
  end
end
