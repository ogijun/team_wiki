# active_record_doctor の設定。`bin/rails active_record_doctor` で全検査。
#
# 除外の方針:
# - Rails/gem が管理するテーブル（Active Storage / Solid Queue 等）は触らないので除外。
# - Solid Queue/Cache/Cable は別DB（config/database.yml の queue/cache/cable）に分離しているため、
#   primary DB しか見ない doctor からは「テーブルが無い」と誤検知される。同じ理由で
#   Action Mailbox / Action Text は未使用（テーブル自体を作っていない）。
ActiveRecordDoctor.configure do
  global :ignore_tables, [
    "ar_internal_metadata", "schema_migrations",
    /\Aactive_storage_/, /\Asolid_queue_/, /\Asolid_cache_/, /\Asolid_cable_/
  ]

  global :ignore_models, [
    /\AActionMailbox::/, /\AActionText::/, /\AActiveStorage::/,
    /\ASolidQueue::/, /\ASolidCache::/, /\ASolidCable::/
  ]

  # SQLite は VARCHAR(n) の n を強制しないため、長さ制限はモデル側の validator が正本。
  # 「schema に length limit が無い」の指摘はこの設計では常に出るので無効化する。
  detector :incorrect_length_validation, enabled: false

  # DB デフォルト値を持つ列（lock_version / position / カウンタ等）は NOT NULL でも
  # presence validator が不要。提案が全部この形なので無効化する。
  detector :missing_presence_validation, enabled: false
end
