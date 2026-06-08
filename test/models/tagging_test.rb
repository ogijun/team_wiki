require "test_helper"

class TaggingTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(email_address: "t@example.com", password: "password123", name: "T")
    @article = Article.create!(title: "Tagged Article", created_by: @user)
  end

  test "tag auto-generates slug" do
    tag = Tag.create!(name: "設計メモ")
    assert_equal "設計メモ", tag.slug
  end

  test "article can have tags through taggings" do
    tag = Tag.create!(name: "ruby")
    @article.tags << tag
    assert_includes @article.reload.tags, tag
    assert_equal @article, tag.reload.articles.first
  end
end
