require "test_helper"

class TaggingTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(email_address: "t@example.com", password: "password123", name: "T")
    @page = Page.create!(title: "Tagged Page", created_by: @user)
  end

  test "tag auto-generates slug" do
    tag = Tag.create!(name: "設計メモ")
    assert_equal "設計メモ", tag.slug
  end

  test "page can have tags through taggings" do
    tag = Tag.create!(name: "ruby")
    @page.tags << tag
    assert_includes @page.reload.tags, tag
    assert_equal @page, tag.reload.pages.first
  end
end
