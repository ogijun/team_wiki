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

  def render(md) = MarkdownRenderer.new(link_resolver: resolver).render(md)

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

  test "output is html_safe" do
    assert render("ok").html_safe?
  end
end
