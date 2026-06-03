require "test_helper"

class ArticleTest < ActiveSupport::TestCase
  setup { @user = User.create!(email_address: "u@example.com", password: "password123", name: "U") }

  test "contributors are distinct revision authors in first-appearance order" do
    bob = User.create!(email_address: "bob@example.com", password: "password123", name: "Bob")
    article = Article.create!(title: "共同編集", created_by: @user)
    ArticleRevisionCreator.call(article: article, body: "1", author: @user)
    ArticleRevisionCreator.call(article: article, body: "2", author: bob)
    ArticleRevisionCreator.call(article: article, body: "3", author: @user)
    assert_equal [@user, bob], article.contributors
  end

  test "requires title" do
    article = Article.new(created_by: @user)
    assert_not article.valid?
    assert article.errors[:title].any?
  end

  test "slug is a random token not derived from title" do
    article = Article.create!(title: "これはテストページです", created_by: @user)
    assert_match(/\A[a-z0-9]{8}\z/, article.slug)
    assert_not_includes article.slug, "テスト"
  end

  test "slug is unique across articles" do
    a = Article.create!(title: "A", created_by: @user)
    b = Article.create!(title: "B", created_by: @user)
    assert_not_equal a.slug, b.slug
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

  test "starts reader wraps stored columns into FuzzyDate" do
    a = Article.create!(title: "年表記事", created_by: @user,
                        starts_at: Time.zone.local(1979, 1, 1), starts_precision: "year")
    assert_equal "1979年", a.starts.label
    assert_nil a.ends
  end

  test "requires starts_at and starts_precision together" do
    a = Article.new(title: "片方", created_by: @user, starts_at: Time.zone.local(1979))
    assert_not a.valid?
    assert a.errors[:starts_precision].any?
  end

  test "rejects invalid precision" do
    a = Article.new(title: "不正精度", created_by: @user,
                    starts_at: Time.zone.local(1979), starts_precision: "decade")
    assert_not a.valid?
  end

  test "ends must not precede starts" do
    a = Article.new(title: "逆転", created_by: @user,
                    starts_at: Time.zone.local(1980), starts_precision: "year",
                    ends_at: Time.zone.local(1979), ends_precision: "year")
    assert_not a.valid?
    assert a.errors[:ends_at].any?
  end

  test "ends requires starts" do
    a = Article.new(title: "終わりだけ", created_by: @user,
                    ends_at: Time.zone.local(1979), ends_precision: "year")
    assert_not a.valid?
    assert a.errors[:starts_at].any?
  end

  test "chronicled scope returns dated articles oldest first" do
    Article.create!(title: "無日付", created_by: @user)
    newer = Article.create!(title: "1990", created_by: @user,
                            starts_at: Time.zone.local(1990), starts_precision: "year")
    older = Article.create!(title: "1980", created_by: @user,
                            starts_at: Time.zone.local(1980), starts_precision: "year")
    assert_equal [older, newer], Article.chronicled.to_a
  end
end
