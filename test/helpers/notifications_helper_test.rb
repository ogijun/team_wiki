require "test_helper"

class NotificationsHelperTest < ActionView::TestCase
  include ApplicationHelper
  include UsersHelper

  test "every notification kind has a display phrase and timeline icon" do
    assert_equal Notification::KINDS.sort, NotificationsHelper::PHRASES.keys.sort
    assert_equal Notification::KINDS.sort, NotificationsHelper::ICONS.keys.sort
  end

  test "every notification icon exists in the sprite" do
    sprite = Rails.root.join("app/assets/images/icons.svg").read
    NotificationsHelper::ICONS.each_value do |name|
      assert_includes sprite, %(id="#{name}"), "icons.svg に symbol '#{name}' がありません"
    end
  end

  test "self-assignment tells the material owner that the work was accepted" do
    owner = create(:user)
    actor = create(:user)
    transcription = create(:transcription, material: create(:material, user: owner), assignee: actor)
    notification = Notification.create!(recipient: owner, actor: actor, kind: "assignment", subject: transcription)

    assert_includes notification_message(notification), "文字起こしを引き受けました"
    refute_includes notification_message(notification), "あなたに"
  end

  test "assignment by another member tells the assignee about the assignment" do
    actor = create(:user)
    assignee = create(:user)
    transcription = create(:transcription, material: create(:material), assignee: assignee)
    notification = Notification.create!(recipient: assignee, actor: actor, kind: "assignment", subject: transcription)

    assert_includes notification_message(notification), "あなたに"
    assert_includes notification_message(notification), "割り当てました"
  end
end
