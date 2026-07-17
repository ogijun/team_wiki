require "test_helper"

class LikeTest < ActiveSupport::TestCase
  test "a user can like a reactable only once and the counter is maintained" do
    reactor = create(:user)
    article = create(:article)

    like = Like.create!(reactor: reactor, reactable: article)
    assert_equal 1, article.reload.likes_count
    assert article.liked_by?(reactor)

    duplicate = Like.new(reactor: reactor, reactable: article)
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:reactor_id], "has already been taken"

    like.destroy!
    assert_equal 0, article.reload.likes_count
    assert_not article.liked_by?(reactor)
  end

  test "like target maps creation activities to their subject and deeds to the activity" do
    user = create(:user)
    article = create(:article, created_by: user)
    created = Activity.record(actor: user, action: "article.created", subject: article)
    edited = Activity.record(actor: user, action: "article.edited", subject: article)

    assert_equal article, created.like_target
    assert_equal edited, edited.like_target
  end

  test "creation activity without its deleted subject falls back to itself" do
    activity = Activity.record(actor: create(:user), action: "article.created", subject_label: "削除済み")

    assert_equal activity, activity.like_target
  end
end
