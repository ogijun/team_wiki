# 年表の統一エントリ: 日付のある記事(chronicled)、発行日のある資料(published_at)、
# 発売日のある発売物(chronicled) を1つの時系列リストにマージして日付昇順で返す純関数。表示専用。
module Chronicle
  module_function

  Entry = Struct.new(:sort_at, :starts, :ends, :title, :record, :kind, keyword_init: true)

  # 同日の並び順（決定的にするための優先度）。
  KIND_ORDER = { article: 0, material: 1, publication: 2 }.freeze

  def entries
    article_entries = Article.chronicled.map do |a|
      Entry.new(sort_at: a.starts_at, starts: a.starts, ends: a.ends, title: a.title, record: a, kind: :article)
    end
    material_entries = Material.where.not(published_at: nil).map do |m|
      Entry.new(sort_at: m.published_at, starts: m.published, ends: nil, title: m.title, record: m, kind: :material)
    end
    publication_entries = Publication.chronicled.map do |p|
      Entry.new(sort_at: p.released_at, starts: p.released, ends: nil, title: p.title, record: p, kind: :publication)
    end
    # 日付昇順。同日は 記事→資料→発売物、さらにタイトルで決定的に並べる。
    (article_entries + material_entries + publication_entries)
      .sort_by { |e| [ e.sort_at, KIND_ORDER.fetch(e.kind), e.title ] }
  end
end
