class CreateLikes < ActiveRecord::Migration[8.1]
  def change
    create_table :likes do |t|
      t.references :reactor, null: false, foreign_key: { to_table: :users }
      t.references :reactable, polymorphic: true, null: false
      t.timestamps
    end

    add_index :likes, %i[reactor_id reactable_type reactable_id], unique: true, name: "index_likes_uniqueness"
  end
end
