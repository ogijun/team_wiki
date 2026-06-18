# 年表(年表)の統一エントリ: 日付のある記事(chronicled)と発行日のある資料(published_at)を
# 1つの時系列リストにマージして日付昇順で返す純関数。表示専用。
module Chronicle
  module_function

  Entry = Struct.new(:sort_at, :starts, :ends, :title, :record, :kind, keyword_init: true)

  def entries
    article_entries = Article.chronicled.map do |a|
      Entry.new(sort_at: a.starts_at, starts: a.starts, ends: a.ends, title: a.title, record: a, kind: :article)
    end
    material_entries = Material.where.not(published_at: nil).map do |m|
      Entry.new(sort_at: m.published_at, starts: m.published, ends: nil, title: m.title, record: m, kind: :material)
    end
    # 日付昇順。同日は記事(0)→資料(1)の安定順。
    (article_entries + material_entries).sort_by { |e| [ e.sort_at, e.kind == :article ? 0 : 1 ] }
  end
end
