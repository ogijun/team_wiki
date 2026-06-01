class MarkdownRenderer
  # link_resolver: callable(title) -> { href:, exists: }
  def initialize(link_resolver:)
    @link_resolver = link_resolver
  end

  def render(markdown)
    # 1. GFM をレンダリング（既定で raw HTML はエスケープ = 安全）
    html = Commonmarker.to_html(markdown.to_s, options: { extension: { table: true, strikethrough: true, autolink: true } })
    # 2. [[タイトル]] をアンカーに置換（renderer が生成する安全な HTML）
    linkified = html.gsub(WikiLinkExtractor::PATTERN) do
      title = Regexp.last_match(1).strip
      next Regexp.last_match(0) if title.empty?
      build_anchor(title)
    end
    linkified.html_safe
  end

  private

  def build_anchor(title)
    info = @link_resolver.call(title) || { href: "#", exists: false }
    css = info[:exists] ? "wikilink" : "wikilink wikilink-new"
    %(<a href="#{info[:href]}" class="#{css}">#{ERB::Util.html_escape(title)}</a>)
  end
end
