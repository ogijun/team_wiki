require "test_helper"

class WikiLinkResolverTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(email_address: "r@example.com", password: "password123", name: "R")
    @article = Article.create!(title: "存在", created_by: @user)
  end

  test "existing title resolves to article path and exists true" do
    info = WikiLinkResolver.call("存在")
    assert info[:exists]
    # path helpers percent-encode unicode slugs
    assert_includes info[:href], CGI.escape(@article.slug)
  end

  test "missing title resolves to new article link with exists false" do
    info = WikiLinkResolver.call("無い")
    assert_not info[:exists]
    assert_includes info[:href], CGI.escape("無い")
  end

  test "resolve_all maps each title in one pass, existing vs missing" do
    map = WikiLinkResolver.resolve_all([ "存在", "無い", "存在" ])
    assert map["存在"][:exists]
    assert_includes map["存在"][:href], CGI.escape(@article.slug)
    assert_not map["無い"][:exists]
    assert_includes map["無い"][:href], CGI.escape("無い")
  end

  test "resolver_for resolves in-body titles and falls back to a single lookup" do
    other = Article.create!(title: "別記事", created_by: @user)
    resolver = WikiLinkResolver.resolver_for("これは [[存在]] へのリンク")
    assert resolver.call("存在")[:exists]        # 本文内 → resolve_all マップ経由
    assert resolver.call("別記事")[:exists]       # 本文外の既存 → 単発 call にフォールバック
    assert_not resolver.call("未作成な記事")[:exists]
    assert_includes resolver.call("別記事")[:href], CGI.escape(other.slug)
  end
end
