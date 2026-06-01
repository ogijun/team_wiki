module WikiLinkExtractor
  module_function

  PATTERN = /\[\[([^\[\]]+?)\]\]/

  def call(markdown)
    markdown.to_s.scan(PATTERN)
            .map { |m| m.first.strip }
            .reject(&:empty?)
            .uniq
  end
end
