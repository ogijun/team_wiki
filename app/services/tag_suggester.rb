# 既存タグを辞書として対象（記事/資料）のテキストに走査し、未付与のヒットをタグ候補として返す。
# 機械は候補を出すだけで、付与は人がワンクリックで確定する（EXIF/PDF 抽出と同じ哲学）。
# 完全一致の包含検索なので分かち書き不要・候補は必ず既存の語彙＝タグが育つほど賢くなる。
module TagSuggester
  module_function

  def call(taggable)
    text = searchable_text(taggable)
    return [] if text.blank?

    attached_ids = taggable.tags.ids
    Tag.where.not(id: attached_ids).select { |tag| text.include?(tag.name) }
  end

  # タイトル・書誌メタデータ全項目・文字起こし・コメントを対象にする。
  def searchable_text(taggable)
    parts =
      case taggable
      when Material
        [ taggable.title, taggable.description, taggable.author, taggable.source,
          taggable.publisher, taggable.volume, taggable.pages, taggable.isbn,
          taggable.transcriptions.map(&:body).join("\n") ]
      when Article
        [ taggable.title, taggable.current_revision&.body ]
      else
        return ""
      end
    (parts + taggable.comments.pluck(:body)).compact.join("\n")
  end
end
