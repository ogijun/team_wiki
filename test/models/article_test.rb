require "test_helper"

class ArticleTest < ActiveSupport::TestCase
  setup { @user = User.create!(email_address: "u@example.com", password: "password123", name: "U") }

  test "requires title" do
    article = Article.new(created_by: @user)
    assert_not article.valid?
    assert article.errors[:title].any?
  end

  test "auto-generates slug from title" do
    article = Article.create!(title: "Hello World", created_by: @user)
    assert_equal "hello-world", article.slug
  end

  test "slug uniqueness appends counter" do
    Article.create!(title: "Dup", created_by: @user)
    second = Article.create!(title: "Dup!", created_by: @user) # slugify -> "dup"
    assert_equal "dup-2", second.slug
  end

  test "title uniqueness enforced" do
    Article.create!(title: "Same", created_by: @user)
    dup = Article.new(title: "Same", created_by: @user)
    assert_not dup.valid?
  end

  test "to_param returns slug" do
    article = Article.create!(title: "Param Me", created_by: @user)
    assert_equal article.slug, article.to_param
  end

  test "destroying an article nullifies its materials" do
    article = Article.create!(title: "NullifyMe", created_by: @user)
    m = Material.create!(user: @user, url: "https://example.com/x", article: article)
    article.destroy
    assert_nil m.reload.article_id
  end
end
