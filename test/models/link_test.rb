require "test_helper"

class LinkTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(email_address: "l@example.com", password: "password123", name: "L")
    @src = Page.create!(title: "Source", created_by: @user)
    @dst = Page.create!(title: "Dest", created_by: @user)
  end

  test "resolved link belongs to target page" do
    link = Link.create!(source_page: @src, target_title: "Dest", target_page_id: @dst.id)
    assert_equal @dst, link.target_page
  end

  test "broken link has nil target page" do
    link = Link.create!(source_page: @src, target_title: "Missing", target_page_id: nil)
    assert_nil link.target_page
  end

  test "page backlinks are inbound resolved links" do
    Link.create!(source_page: @src, target_title: "Dest", target_page_id: @dst.id)
    assert_includes @dst.inbound_links.map(&:source_page), @src
  end
end
