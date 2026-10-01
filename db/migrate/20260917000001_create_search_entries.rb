class CreateSearchEntries < ActiveRecord::Migration[8.1]
  # FTS5 の仮想表。列の並びは bm25() の重みの並びと対応する（SearchRunner）。
  def change
    create_virtual_table :search_entries, :fts5, [
      "kind UNINDEXED",
      "record_id UNINDEXED",
      "owner_kind UNINDEXED",
      "owner_id UNINDEXED",
      "title",
      "body",
      "tags",
      "tokenize = 'trigram case_sensitive 0'"
    ]
  end
end
