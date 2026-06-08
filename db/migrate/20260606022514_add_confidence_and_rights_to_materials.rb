class AddConfidenceAndRightsToMaterials < ActiveRecord::Migration[8.1]
  def change
    add_column :materials, :confidence, :string, null: false, default: "unconfirmed"
    add_column :materials, :rights, :string
    add_index :materials, :confidence
    add_index :materials, :rights
  end
end
