require "test_helper"

class PageTest < ActiveSupport::TestCase
  setup { @user = User.create!(email_address: "u@example.com", password: "password123", name: "U") }

  test "requires title" do
    page = Page.new(created_by: @user)
    assert_not page.valid?
    assert page.errors[:title].any?
  end

  test "auto-generates slug from title" do
    page = Page.create!(title: "Hello World", created_by: @user)
    assert_equal "hello-world", page.slug
  end

  test "slug uniqueness appends counter" do
    Page.create!(title: "Dup", created_by: @user)
    second = Page.create!(title: "Dup!", created_by: @user) # slugify -> "dup"
    assert_equal "dup-2", second.slug
  end

  test "title uniqueness enforced" do
    Page.create!(title: "Same", created_by: @user)
    dup = Page.new(title: "Same", created_by: @user)
    assert_not dup.valid?
  end

  test "to_param returns slug" do
    page = Page.create!(title: "Param Me", created_by: @user)
    assert_equal page.slug, page.to_param
  end

  test "destroying a page nullifies its materials" do
    page = Page.create!(title: "NullifyMe", created_by: @user)
    m = Material.create!(user: @user, url: "https://example.com/x", page: page)
    page.destroy
    assert_nil m.reload.page_id
  end
end
