class MarkdownRenderer
  Result = Struct.new(:html, :references, keyword_init: true)
  Reference = Struct.new(:number, :material, :handle, keyword_init: true)

  REF_PATTERN = /\[\[ref:([^\[\]]+?)\]\]/

  # link_resolver: callable(title) -> { href:, exists: }
  # ref_resolver:  callable(handle) -> Material or nil
  def initialize(link_resolver:, ref_resolver: ->(_) { nil })
    @link_resolver = link_resolver
    @ref_resolver = ref_resolver
  end

  def render(markdown)
    # Commonmarker は UTF-8 以外を拒否する（nil.to_s は US-ASCII）。境界でそろえる。
    source = markdown.to_s
    source = source.encode(Encoding::UTF_8) unless source.encoding == Encoding::UTF_8
    # 1. GFM をレンダリング（既定で raw HTML はエスケープ = 安全）
    html = Commonmarker.to_html(source, options: { extension: { table: true, strikethrough: true, autolink: true } })

    references = []
    numbers = {}
    # 2. 出典 [[ref:handle]] を先に消費（Wikiリンクと衝突させない）
    html = html.gsub(REF_PATTERN) { build_ref(Regexp.last_match(1).strip, references, numbers) }
    # 3. [[タイトル]] をアンカーに置換（renderer が生成する安全な HTML）
    html = html.gsub(WikiLinkExtractor::PATTERN) do
      title = Regexp.last_match(1).strip
      next Regexp.last_match(0) if title.empty?
      build_anchor(title)
    end

    Result.new(html: html.html_safe, references: references)
  end

  private

  def build_ref(handle, references, numbers)
    material = @ref_resolver.call(handle)
    unless material
      return %(<sup class="ref ref-broken">[壊れた出典: #{ERB::Util.html_escape(handle)}]</sup>)
    end
    number = numbers[handle] ||= begin
      n = references.size + 1
      references << Reference.new(number: n, material: material, handle: handle)
      n
    end
    %(<sup class="ref"><a href="#ref-#{number}">[#{number}]</a></sup>)
  end

  def build_anchor(title)
    info = @link_resolver.call(title) || { href: "#", exists: false }
    css = info[:exists] ? "wikilink" : "wikilink wikilink-new"
    %(<a href="#{info[:href]}" class="#{css}">#{ERB::Util.html_escape(title)}</a>)
  end
end
