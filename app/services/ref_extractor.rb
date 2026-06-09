# 本文から引用ハンドル（[[ref:handle]] の handle = 資料slug）を抽出する。
# WikiLinkExtractor の引用版。重複は除去し出現順を保つ。
module RefExtractor
  module_function

  PATTERN = /\[\[ref:([^\[\]]+?)\]\]/

  def call(markdown)
    markdown.to_s.scan(PATTERN)
            .map { |m| m.first.strip }
            .reject(&:empty?)
            .uniq
  end
end
