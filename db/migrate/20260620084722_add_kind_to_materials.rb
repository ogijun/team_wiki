class AddKindToMaterials < ActiveRecord::Migration[8.1]
  def change
    add_column :materials, :kind, :string
  end
end
