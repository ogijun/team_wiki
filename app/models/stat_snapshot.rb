# サイト統計の日次スナップショット（積み上げ履歴グラフ用）。
# StatSnapshotJob が毎日 JST 23:55 に capture! する。同日再実行は同じ行を更新（冪等）。
class StatSnapshot < ApplicationRecord
  validates :date, presence: true, uniqueness: true

  # 現在値の単一の算出窓口（ホームの統計表示とスナップショットで共用）。
  def self.current_values
    library = Material.library_summary
    {
      articles_count: Article.count,
      materials_count: Material.count,
      # confidence は撤去済み（#133）。unconfirmed_materials_count はもう記録しない（カラムは休眠）。
      # SQLite の LENGTH(text) は文字数（バイト数ではない）を返す
      transcribed_chars: Transcription.sum("LENGTH(body)").to_i,
      total_file_bytes: library[:total_bytes],
      total_pages: library[:total_pages]
    }
  end

  def self.capture!(date: Date.current)
    snapshot = find_or_initialize_by(date: date)
    snapshot.update!(current_values)
    snapshot
  end
end
