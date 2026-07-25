require "test_helper"

class NotificationTest < ActiveSupport::TestCase
  test "emit creates a notification for another user" do
    recipient = create(:user)
    recipient.update_column(:created_at, 1.hour.ago)
    actor = create(:user)
    subject = create(:article, created_by: recipient)

    assert_difference("Notification.count", 1) do
      Notification.emit(recipient: recipient, actor: actor, kind: "like", subject: subject)
    end
    notification = Notification.last
    assert_equal recipient, notification.recipient
    assert_equal actor, notification.actor
    assert_equal subject, notification.subject
  end

  test "emit suppresses self notifications" do
    user = create(:user)

    assert_no_difference("Notification.count") do
      Notification.emit(recipient: user, actor: user, kind: "comment", subject: create(:article, created_by: user))
    end
  end

  test "emit touches an existing unread duplicate instead of creating another" do
    recipient = create(:user)
    recipient.update_column(:created_at, 1.hour.ago)
    actor = create(:user)
    subject = create(:article, created_by: recipient)
    existing = Notification.create!(recipient: recipient, actor: actor, kind: "like", subject: subject, created_at: 1.minute.ago, updated_at: 1.minute.ago)

    assert_no_difference("Notification.count") { Notification.emit(recipient: recipient, actor: actor, kind: "like", subject: subject) }
    assert_operator existing.reload.updated_at, :>, 30.seconds.ago
  end

  test "emit creates another notification after the existing one was seen" do
    recipient = create(:user, notifications_seen_at: Time.current)
    actor = create(:user)
    subject = create(:article, created_by: recipient)
    Notification.create!(recipient: recipient, actor: actor, kind: "like", subject: subject, created_at: 1.minute.ago)

    assert_difference("Notification.count", 1) { Notification.emit(recipient: recipient, actor: actor, kind: "like", subject: subject) }
  end

  test "dedupe_unread keeps the oldest notification and latest update time" do
    recipient = create(:user)
    recipient.update_column(:created_at, 1.hour.ago)
    actor = create(:user)
    subject = create(:article, created_by: recipient)
    oldest = Notification.create!(recipient: recipient, actor: actor, kind: "like", subject: subject, created_at: 3.minutes.ago, updated_at: 3.minutes.ago)
    Notification.create!(recipient: recipient, actor: actor, kind: "like", subject: subject, created_at: 2.minutes.ago, updated_at: 1.minute.ago)

    Notification.dedupe_unread!

    assert_equal [ oldest.id ], Notification.where(recipient: recipient).pluck(:id)
    assert_operator oldest.reload.updated_at, :>, 90.seconds.ago
  end

  test "kind is restricted" do
    notification = Notification.new(recipient: create(:user), actor: create(:user), kind: "unknown", subject: create(:article))
    assert_not notification.valid?
  end

  test "destroying a subject removes its notifications" do
    recipient = create(:user)
    comment = create(:comment)
    Notification.create!(recipient: recipient, actor: comment.author, kind: "comment", subject: comment)

    assert_difference("Notification.count", -1) { comment.destroy! }
  end
end
