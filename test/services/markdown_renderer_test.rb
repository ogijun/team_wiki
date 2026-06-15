require "test_helper"

class MarkdownRendererTest < ActiveSupport::TestCase
  # resolver: title -> { href:, exists: } or nil(=未作成)
  def resolver
    ->(title) do
      if title == "存在ページ"
        { href: "/pages/exists", exists: true }
      else
        { href: "/pages/new?title=#{title}", exists: false }
      end
    end
  end

  def render(md) = MarkdownRenderer.new(link_resolver: resolver).render(md).html

  def render_full(md, ref_map = {})
    MarkdownRenderer.new(link_resolver: resolver, ref_resolver: ->(h) { ref_map[h] }).render(md)
  end

  test "renders markdown headings" do
    assert_includes render("# 見出し"), "<h1>"
  end

  test "existing wikilink becomes anchor with wikilink class" do
    html = render("[[存在ページ]]")
    assert_includes html, 'href="/pages/exists"'
    assert_includes html, 'class="wikilink"'
    assert_includes html, "存在ページ"
  end

  test "missing wikilink gets wikilink-new class" do
    html = render("[[新規]]")
    assert_includes html, "wikilink-new"
    assert_includes html, "title=新規"
  end

  test "sanitizes raw html / script" do
    html = render("<script>alert(1)</script>")
    assert_not_includes html, "<script>"
  end

  test "output html is html_safe" do
    assert_predicate render("ok"), :html_safe?
  end

  test "ref becomes numbered footnote and is collected" do
    mat = Object.new
    result = render_full("主張[[ref:abc12345]]", { "abc12345" => mat })
    assert_includes result.html, '<sup class="ref"><a href="#ref-1">[1]</a></sup>'
    assert_equal 1, result.references.size
    assert_equal mat, result.references.first.material
    assert_equal 1, result.references.first.number
    assert_equal "abc12345", result.references.first.handle
  end

  test "duplicate ref to same handle reuses number and single entry" do
    mat = Object.new
    result = render_full("a[[ref:h1]] b[[ref:h1]]", { "h1" => mat })
    assert_equal 2, result.html.scan('href="#ref-1"').size
    assert_equal 1, result.references.size
  end

  test "multiple materials numbered in appearance order" do
    m1 = Object.new
    m2 = Object.new
    result = render_full("x[[ref:h1]] y[[ref:h2]]", { "h1" => m1, "h2" => m2 })
    assert_equal [ 1, 2 ], result.references.map(&:number)
    assert_equal [ m1, m2 ], result.references.map(&:material)
  end

  test "broken ref shows red marker and is not collected" do
    result = render_full("x[[ref:missing1]]", {})
    assert_includes result.html, "ref-broken"
    assert_includes result.html, "壊れた出典"
    assert_empty result.references
  end

  test "ref syntax is not turned into a wikilink" do
    result = render_full("[[ref:abc12345]]", { "abc12345" => Object.new })
    assert_not_includes result.html, "wikilink"
  end

  test "no refs yields empty references" do
    result = render_full("ただの本文")
    assert_empty result.references
  end

  test "renders nil and non-UTF-8 input without raising" do
    # nil.to_s は US-ASCII。Commonmarker は UTF-8 必須なので境界で変換される。
    assert_equal "", render(nil).strip
    assert_includes render("plain".encode(Encoding::US_ASCII)), "plain"
  end
end
