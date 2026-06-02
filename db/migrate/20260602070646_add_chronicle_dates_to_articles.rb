class AddChronicleDatesToArticles < ActiveRecord::Migration[8.1]
  def change
    add_column :articles, :starts_at, :datetime
    add_column :articles, :starts_precision, :string
    add_column :articles, :ends_at, :datetime
    add_column :articles, :ends_precision, :string
    add_index :articles, :starts_at
  end
end
