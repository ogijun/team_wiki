# 検索の実行。SearchQuery を受け取り、search_entries を MATCH（＋短い語は LIKE）で引き、
# owner（遷移先）ごとに最良スコアで畳んで返す。
module SearchRunner
  module_function

  Hit = Struct.new(:owner, :via, :score, keyword_init: true)

  BM25 = "bm25(search_entries, 0, 0, 0, 0, 5.0, 1.0, 2.0)"
  LIKE_COLUMNS = %w[title body tags].freeze

  def call(query)
    return [] if query.blank?
    return [] unless query.fts? || query.short_terms.any?

    fold(fetch(query))
  rescue ActiveRecord::StatementInvalid => e
    Rails.logger.warn("SearchRunner fell back to LIKE: #{e.class}: #{e.message}")
    fold(legacy_like_rows(query))
  end

  def fetch(query)
    where = []
    binds = []
    if query.fts?
      where << "search_entries MATCH ?"
      binds << query.to_fts5
    end
    query.short_terms.each do |term|
      where << "(#{LIKE_COLUMNS.map { |column| "#{column} LIKE ?" }.join(' OR ')})"
      binds.concat([ like(term) ] * LIKE_COLUMNS.size)
    end
    like_excludes = query.short_excludes + (query.fts? ? [] : query.excludes)
    like_excludes.each do |term|
      where << "NOT (#{LIKE_COLUMNS.map { |column| "#{column} LIKE ?" }.join(' OR ')})"
      binds.concat([ like(term) ] * LIKE_COLUMNS.size)
    end
    score = query.fts? ? BM25 : "0"
    order = query.fts? ? "score, kind, title" : "kind, title"
    sql = <<~SQL.squish
      SELECT kind, record_id, owner_kind, owner_id, #{score} AS score
      FROM search_entries
      WHERE #{where.join(' AND ')}
      ORDER BY #{order}
    SQL
    connection.select_all(ActiveRecord::Base.sanitize_sql_array([ sql, *binds ])).to_a
  end

  def like(term) = "%#{ActiveRecord::Base.sanitize_sql_like(term)}%"

  def fold(rows)
    best = rows.uniq { |row| [ row["owner_kind"], row["owner_id"].to_s ] }
    owners = load_records(best.map { |row| [ row["owner_kind"], row["owner_id"] ] })
    vias = load_records(best.map { |row| [ row["kind"].camelize, row["record_id"] ] })
    best.filter_map do |row|
      owner = owners[[ row["owner_kind"], row["owner_id"].to_i ]]
      via = vias[[ row["kind"].camelize, row["record_id"].to_i ]]
      next unless owner && via

      Hit.new(owner: owner, via: via, score: row["score"].to_f)
    end
  end

  def load_records(pairs)
    pairs.group_by(&:first).each_with_object({}) do |(class_name, group), records|
      class_name.constantize.where(id: group.map { |_, id| id.to_i }).each do |record|
        records[[ class_name, record.id ]] = record
      end
    end
  end

  def legacy_like_rows(query)
    words = query.terms + query.phrases + query.short_terms
    return [] if words.empty?

    pattern = like(words.first)
    articles = Article.joins(:current_revision)
                      .where("articles.title LIKE :q OR revisions.body LIKE :q", q: pattern).distinct
    materials = Material.left_joins(:transcriptions)
                        .where("materials.title LIKE :q OR transcriptions.body LIKE :q", q: pattern).distinct
    (articles.to_a + materials.to_a).sort_by(&:updated_at).reverse.map do |record|
      {
        "kind" => record.class.name.underscore, "record_id" => record.id,
        "owner_kind" => record.class.name, "owner_id" => record.id, "score" => 0
      }
    end
  end

  def connection = ActiveRecord::Base.connection
end
