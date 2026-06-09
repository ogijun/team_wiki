class RemoveMemoFromMaterials < ActiveRecord::Migration[8.1]
  def change
    # メモは複数コメント（polymorphic Comment）へ移行。既存の memo 値は破棄する。
    remove_column :materials, :memo, :text
  end
end
