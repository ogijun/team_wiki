module SearchHelper
  # 最初のマッチ位置の前後 radius 文字を切り出し、マッチを <mark> でハイライトして返す。
  # 周辺テキストは Rails の highlight がエスケープする。マッチが無ければ nil（呼び出し側で非表示）。
  def search_snippet(text, query, radius: 40)
    return nil if text.blank? || query.blank?
    index = text.downcase.index(query.downcase)
    return nil if index.nil?

    from = [ index - radius, 0 ].max
    to = [ index + query.length + radius, text.length ].min
    snippet = text[from...to].gsub(/\s+/, " ")
    # safe_join が周辺テキストをエスケープし、マッチ部分だけ <mark> にする
    # （Rails の highlight は sanitize で <b> 等の許可タグを素通しするため使わない）。
    parts = snippet.split(/(#{Regexp.escape(query)})/i).map do |part|
      part.casecmp?(query) ? tag.mark(part) : part
    end
    safe_join([ (from.positive? ? "…" : ""), *parts, (to < text.length ? "…" : "") ])
  end
end
