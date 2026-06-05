class AddMetadataToArticlesAndMaterials < ActiveRecord::Migration[8.1]
  def change
    add_column :articles, :kind, :string
    add_column :articles, :status, :string, null: false, default: "stub"
    add_index :articles, :kind
    add_index :articles, :status

    add_column :materials, :source, :string
    add_column :materials, :author, :string
    add_column :materials, :published_at, :datetime
    add_column :materials, :published_precision, :string
    add_column :materials, :retrieved_on, :date
  end
end
