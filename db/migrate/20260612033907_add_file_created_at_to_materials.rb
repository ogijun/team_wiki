class AddFileCreatedAtToMaterials < ActiveRecord::Migration[8.1]
  def change
    add_column :materials, :file_created_at, :datetime
  end
end
