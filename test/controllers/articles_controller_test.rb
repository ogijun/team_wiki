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
end
