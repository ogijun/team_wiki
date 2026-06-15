class AddPartsToTranscriptions < ActiveRecord::Migration[8.1]
  def up
    add_column :transcriptions, :label, :string
    # 既存行・position 未指定の作成は先頭パート(1)。複数パートはコントローラが max+1 を明示採番する。
    add_column :transcriptions, :position, :integer, null: false, default: 1
    add_reference :transcriptions, :assignee, foreign_key: { to_table: :users }, null: true
    add_column :transcriptions, :lock_version, :integer, null: false, default: 0

    # 1資料1件の unique 制約を撤去し、複数パートを許可（検索用に非 unique index は残す）。
    remove_index :transcriptions, column: :material_id
    add_index :transcriptions, :material_id
  end

  def down
    remove_column :transcriptions, :label
    remove_column :transcriptions, :position
    remove_reference :transcriptions, :assignee
    remove_column :transcriptions, :lock_version
    remove_index :transcriptions, column: :material_id
    add_index :transcriptions, :material_id, unique: true
  end
end
