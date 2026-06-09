require "test_helper"

class CommentsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(email_address: "co@example.com", name: "CO", provider: "discord", uid: "co-user")
    sign_in_as(@user)
    @article = Article.create!(title: "コメント記事", created_by: @user)
    @material = Material.create!(user: @user, url: "https://example.com/c", title: "コメント資料")
  end

  test "posts a comment on an article and records a comment.posted activity" do
    assert_difference [ "Comment.count", "Activity.where(action: 'comment.posted').count" ], 1 do
      post article_comments_url(@article), params: { comment: { body: "記事コメント" } }
    end
    assert_redirected_to article_url(@article)
    assert_equal "記事コメント", @article.comments.last.body
    assert_equal 1, @article.reload.comments_count
  end

  test "posts a comment on a material" do
    assert_difference "Comment.count", 1 do
      post material_comments_url(@material), params: { comment: { body: "資料コメント" } }
    end
    assert_redirected_to material_url(@material)
    assert_equal 1, @material.reload.comments_count
  end

  test "blank comment is rejected" do
    assert_no_difference "Comment.count" do
      post article_comments_url(@article), params: { comment: { body: "" } }
    end
    assert_redirected_to article_url(@article)
  end

  test "author can delete own comment" do
    c = @article.comments.create!(body: "消す", author: @user)
    assert_difference "Comment.count", -1 do
      delete comment_url(c)
    end
    assert_redirected_to article_url(@article)
  end

  test "non-author non-admin cannot delete" do
    other = User.create!(email_address: "ot2@example.com", name: "OT2", provider: "discord", uid: "ot2")
    c = @article.comments.create!(body: "他人の", author: other)
    assert_no_difference "Comment.count" do
      delete comment_url(c)
    end
  end

  test "admin can delete any comment" do
    other = User.create!(email_address: "ot3@example.com", name: "OT3", provider: "discord", uid: "ot3")
    c = @article.comments.create!(body: "管理者が消す", author: other)
    admin = User.create!(email_address: "adm@example.com", name: "ADM", provider: "discord", uid: "adm", role: "admin")
    sign_in_as(admin)
    # ログインフローが DB の role を Discord から再計算（→editor）するので、確実に admin へ戻す。
    admin.update_column(:role, "admin")
    assert_difference "Comment.count", -1 do
      delete comment_url(c)
    end
  end
end
