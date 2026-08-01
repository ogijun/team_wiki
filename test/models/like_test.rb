require "test_helper"

class LikeTest < ActiveSupport::TestCase
  test "reactable types and concern includes stay in sync" do
    Rails.application.eager_load!
    included = ApplicationRecord.descendants.select { |model| model.include?(Reactable) }.map(&:name)

    assert_equal Like::REACTABLE_TYPES.sort, included.sort
    assert_not_includes Tag.included_modules, Reactable
  end

  test "reactable models retain like counter caches" do
    user = create(:user)
    reactables = [
      create(:article),
      create(:material),
      create(:comment),
      create(:transcription),
      Publication.create!(title: "Like対象の本", kind: "book", registered_by: create(:user)),
      Activity.record(actor: create(:user), action: "article.created", subject: create(:article))
    ]

    reactables.each do |reactable|
      Like.create!(reactor: user, reactable: reactable)
      assert_equal 1, reactable.reload.likes_count
    end
  end

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

  test "publication registration is a creation action whose like flows to the publication" do
    user = create(:user)
    publication = Publication.create!(title: "Like対象の本", kind: "book", registered_by: user)
    registered = Activity.record(actor: user, action: "publication.registered", subject: publication)

    assert_equal publication, registered.like_target

    Like.create!(reactor: create(:user), reactable: registered.like_target)
    assert_equal 1, publication.reload.likes_count
  end
end
