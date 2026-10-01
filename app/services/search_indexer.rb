# 全文検索の索引 search_entries への唯一の書き込み口。
# 索引は導出データで、rebuild! によりいつでも作り直せる。
module SearchIndexer
  module_function

  INDEXED_MODELS = [ Article, Material, Transcription, Comment, Publication ].freeze

  def reindex(record)
    remove(record)
    entry = entry_for(record)
    insert(entry) if entry
  end

  def remove(record)
    exec("DELETE FROM search_entries WHERE kind = ? AND record_id = ?", kind_of(record), record.id)
  end

  def rebuild!
    exec("DELETE FROM search_entries")
    count = 0
    INDEXED_MODELS.each do |model|
      model.find_each do |record|
        entry = entry_for(record)
        next unless entry

        insert(entry)
        count += 1
      end
    end
    count
  end

  def count
    connection.select_value("SELECT count(*) FROM search_entries").to_i
  end

  def entry_for(record)
    case record
    when Article
      body = record.current_revision&.body
      return if body.nil?

      row(record, owner: record, title: record.title, body: body, tags: tag_names(record))
    when Material
      body = [ record.source, record.author, record.publisher, record.volume, record.description ].compact_blank.join("\n")
      row(record, owner: record, title: record.title, body: body, tags: tag_names(record))
    when Transcription
      row(record, owner: record.material, title: record.label, body: record.body, tags: "")
    when Comment
      row(record, owner: record.commentable, title: "", body: record.body, tags: "")
    when Publication
      row(record, owner: record, title: record.title, body: "", tags: "")
    end
  end

  def row(record, owner:, title:, body:, tags:)
    {
      kind: kind_of(record), record_id: record.id,
      owner_kind: owner.class.name, owner_id: owner.id,
      title: SearchNormalizer.call(title), body: SearchNormalizer.call(body), tags: SearchNormalizer.call(tags)
    }
  end

  def kind_of(record) = record.class.name.underscore
  def tag_names(record) = record.tags.map(&:name).join(" ")

  def insert(entry)
    exec(<<~SQL.squish, entry[:kind], entry[:record_id], entry[:owner_kind], entry[:owner_id], entry[:title], entry[:body], entry[:tags])
      INSERT INTO search_entries (kind, record_id, owner_kind, owner_id, title, body, tags)
      VALUES (?, ?, ?, ?, ?, ?, ?)
    SQL
  end

  def exec(sql, *binds)
    connection.execute(ActiveRecord::Base.sanitize_sql_array([ sql, *binds ]))
  end

  def connection = ActiveRecord::Base.connection
end
