require "test_helper"

class NotificationTest < ActiveSupport::TestCase
  test "emit creates a notification for another user" do
    recipient = create(:user)
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

  test "kind is restricted" do
    notification = Notification.new(recipient: create(:user), actor: create(:user), kind: "unknown", subject: create(:article))
    assert_not notification.valid?
  end
end
