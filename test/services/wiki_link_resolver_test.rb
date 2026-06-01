require "test_helper"

class WikiLinkResolverTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(email_address: "r@example.com", password: "password123", name: "R")
    @page = Page.create!(title: "存在", created_by: @user)
  end

  test "existing title resolves to page path and exists true" do
    info = WikiLinkResolver.new.call("存在")
    assert info[:exists]
    # path helpers percent-encode unicode slugs
    assert_includes info[:href], CGI.escape(@page.slug)
  end

  test "missing title resolves to new page link with exists false" do
    info = WikiLinkResolver.new.call("無い")
    assert_not info[:exists]
    assert_includes info[:href], CGI.escape("無い")
  end
end
