class ReplaceRetrievedOnWithMemoOnMaterials < ActiveRecord::Migration[8.1]
  def change
    remove_column :materials, :retrieved_on, :date
    add_column :materials, :memo, :text
  end
end
