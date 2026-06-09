module WikiLinkExtractor
  module_function

  PATTERN = /\[\[([^\[\]]+?)\]\]/

  def call(markdown)
    markdown.to_s.scan(PATTERN)
            .map { |m| m.first.strip }
            .reject(&:empty?)
            .reject { |t| t.start_with?("ref:") } # [[ref:slug]] は引用＝WikiリンクではないのでRefExtractorの領分
            .uniq
  end
end
