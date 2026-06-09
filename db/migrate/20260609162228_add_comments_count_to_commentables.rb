class AddCommentsCountToCommentables < ActiveRecord::Migration[8.1]
  def change
    add_column :articles, :comments_count, :integer, default: 0, null: false
    add_column :materials, :comments_count, :integer, default: 0, null: false
  end
end
