class AddPageCountToMaterials < ActiveRecord::Migration[8.1]
  def change
    add_column :materials, :page_count, :integer
  end
end
