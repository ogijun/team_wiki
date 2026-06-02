require "test_helper"

class ArticlesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(email_address: "p@example.com", password: "password123", name: "P")
  end

  def login
    post session_url, params: { email_address: @user.email_address, password: "password123" }
  end

  test "index requires login" do
    get articles_url
    assert_redirected_to new_session_url
  end

  test "create makes article with first revision" do
    login
    assert_difference("Article.count", 1) do
      post articles_url, params: { article: { title: "新記事", body: "本文 [[他]]", tag_names: "ruby" } }
    end
    article = Article.find_by(title: "新記事")
    assert_equal "本文 [[他]]", article.current_revision.body
    assert_redirected_to article_url(article)
  end

  test "show renders current revision body" do
    login
    article = Article.create!(title: "表示", created_by: @user)
    ArticleRevisionCreator.call(article: article, body: "# 見出し", author: @user)
    get article_url(article)
    assert_response :success
    assert_select "h1", text: "見出し"
  end

  test "update creates a new revision" do
    login
    article = Article.create!(title: "更新", created_by: @user)
    ArticleRevisionCreator.call(article: article, body: "旧", author: @user)
    assert_difference("article.revisions.count", 1) do
      patch article_url(article), params: { article: { title: "更新", body: "新", tag_names: "" } }
    end
    assert_equal "新", article.reload.current_revision.body
  end

  test "create records article.created activity" do
    login
    assert_difference("Activity.where(action: 'article.created').count", 1) do
      post articles_url, params: { article: { title: "記録新規", body: "本文" } }
    end
  end

  test "update records article.edited activity" do
    login
    article = Article.create!(title: "記録更新", created_by: @user)
    ArticleRevisionCreator.call(article: article, body: "旧", author: @user)
    assert_difference("Activity.where(action: 'article.edited').count", 1) do
      patch article_url(article), params: { article: { title: article.title, body: "新" } }
    end
  end

  test "destroy records article.deleted activity with label" do
    login
    article = Article.create!(title: "記録削除", created_by: @user)
    assert_difference("Activity.where(action: 'article.deleted').count", 1) do
      delete article_url(article)
    end
    assert_equal "記録削除", Activity.where(action: "article.deleted").order(:id).last.subject_label
  end

  test "create stores fuzzy start with year precision" do
    login
    post articles_url, params: { article: {
      title: "年だけ", body: "x",
      start_year: "1979", start_month: "", start_day: "", start_hour: "", start_minute: ""
    } }
    a = Article.find_by(title: "年だけ")
    assert_equal "year", a.starts_precision
    assert_equal Time.zone.local(1979, 1, 1), a.starts_at
    assert_nil a.ends_at
  end

  test "create stores fuzzy range with day and month precision" do
    login
    post articles_url, params: { article: {
      title: "期間", body: "x",
      start_year: "1939", start_month: "9", start_day: "1", start_hour: "", start_minute: "",
      end_year: "1945", end_month: "8", end_day: "", end_hour: "", end_minute: ""
    } }
    a = Article.find_by(title: "期間")
    assert_equal "day", a.starts_precision
    assert_equal Time.zone.local(1939, 9, 1), a.starts_at
    assert_equal "month", a.ends_precision
    assert_equal Time.zone.local(1945, 8, 1), a.ends_at
  end

  test "update can set fuzzy date" do
    login
    article = Article.create!(title: "あとで日付", created_by: @user)
    ArticleRevisionCreator.call(article: article, body: "本文", author: @user)
    patch article_url(article), params: { article: {
      title: article.title, body: "本文",
      start_year: "2000", start_month: "1", start_day: "", start_hour: "", start_minute: ""
    } }
    assert_equal "month", article.reload.starts_precision
    assert_equal Time.zone.local(2000, 1, 1), article.starts_at
  end
end
