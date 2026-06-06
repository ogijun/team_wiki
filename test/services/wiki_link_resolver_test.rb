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
end
