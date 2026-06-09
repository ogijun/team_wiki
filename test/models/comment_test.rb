require "test_helper"

class CommentTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(email_address: "cm@example.com", name: "CM", provider: "discord", uid: "cm-user")
    @article = Article.create!(title: "コメント対象", created_by: @user)
  end

  test "valid with body, author, commentable" do
    c = Comment.new(commentable: @article, author: @user, body: "コメント本文")
    assert c.valid?, c.errors.full_messages.join(", ")
  end

  test "requires body" do
    c = Comment.new(commentable: @article, author: @user, body: "")
    assert_not c.valid?
    assert c.errors[:body].any?
  end

  test "increments the commentable comments_count via counter_cache" do
    assert_difference -> { @article.reload.comments_count }, 1 do
      Comment.create!(commentable: @article, author: @user, body: "x")
    end
  end

  test "deletable only by the author or an admin" do
    admin = User.create!(email_address: "ad@example.com", name: "AD", provider: "discord", uid: "ad", role: "admin")
    other = User.create!(email_address: "ot@example.com", name: "OT", provider: "discord", uid: "ot")
    c = Comment.create!(commentable: @article, author: @user, body: "x")
    assert c.deletable_by?(@user)
    assert c.deletable_by?(admin)
    assert_not c.deletable_by?(other)
    assert_not c.deletable_by?(nil)
  end

  test "works on a material too (polymorphic)" do
    m = Material.create!(user: @user, url: "https://example.com/x", title: "資料")
    c = Comment.create!(commentable: m, author: @user, body: "資料コメント")
    assert_equal 1, m.reload.comments_count
    assert_includes m.comments, c
  end
end
