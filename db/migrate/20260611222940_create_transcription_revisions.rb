class CreateTranscriptionRevisions < ActiveRecord::Migration[8.1]
  def up
    create_table :transcription_revisions do |t|
      t.references :transcription, null: false, foreign_key: true
      t.references :author, null: false, foreign_key: { to_table: :users }
      t.text :body, null: false
      t.datetime :created_at, null: false
    end

    # 既存の文字起こしは現本文を「初版」としてバックフィル（author=現在の最終更新者）。
    execute <<~SQL
      INSERT INTO transcription_revisions (transcription_id, author_id, body, created_at)
      SELECT id, author_id, body, updated_at FROM transcriptions
    SQL
  end

  def down
    drop_table :transcription_revisions
  end
end
