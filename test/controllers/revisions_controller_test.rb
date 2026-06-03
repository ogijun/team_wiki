require "test_helper"

class RevisionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(email_address: "rv@example.com", name: "RV", provider: "discord", uid: "rev-user")
    sign_in_as(@user)
    @article = Article.create!(title: "Hist", created_by: @user)
    @r1 = ArticleRevisionCreator.call(article: @article, body: "一行目", author: @user)
    @r2 = ArticleRevisionCreator.call(article: @article, body: "一行目\n二行目", author: @user)
  end

  test "index lists revisions newest first" do
    get article_revisions_url(@article)
    assert_response :success
    assert_select "li", minimum: 2
  end

  test "index links each revision to a diff against the previous one" do
    get article_revisions_url(@article)
    assert_response :success
    assert_select "a[href=?]", article_revision_path(@article, @r2, a: @r1.id), text: /前の版との差分/
    assert_select "a", text: "前の版との差分", count: 1
  end

  test "show with a and b shows a diff" do
    get article_revision_url(@article, @r2), params: { a: @r1.id }
    assert_response :success
    assert_select ".diff"
  end

  test "restore creates a new revision from an old body" do
    assert_difference("@article.revisions.count", 1) do
      post restore_article_revision_url(@article, @r1)
    end
    assert_equal "一行目", @article.reload.current_revision.body
  end

  test "restore records article.edited activity" do
    assert_difference("Activity.where(action: 'article.edited').count", 1) do
      post restore_article_revision_url(@article, @r1)
    end
  end
end
