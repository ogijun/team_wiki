class AddOwnershipToMaterials < ActiveRecord::Migration[8.1]
  def change
    # 実物の所持状況（nil=未設定 / original=原本所有 / partial=部分所有 / none=未所持(データのみ)）。
    add_column :materials, :ownership, :string
    add_index :materials, :ownership
  end
end
