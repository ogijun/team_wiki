require "test_helper"

class LinkTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(email_address: "l@example.com", password: "password123", name: "L")
    @src = Article.create!(title: "Source", created_by: @user)
    @dst = Article.create!(title: "Dest", created_by: @user)
  end

  test "resolved link belongs to target article" do
    link = Link.create!(source_article: @src, target_title: "Dest", target_article_id: @dst.id)
    assert_equal @dst, link.target_article
  end

  test "broken link has nil target article" do
    link = Link.create!(source_article: @src, target_title: "Missing", target_article_id: nil)
    assert_nil link.target_article
  end

  test "article backlinks are inbound resolved links" do
    Link.create!(source_article: @src, target_title: "Dest", target_article_id: @dst.id)
    assert_includes @dst.inbound_links.map(&:source_article), @src
  end
end
