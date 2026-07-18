require "test_helper"

class NotificationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @recipient = create(:user)
    @actor = create(:user)
    @article = create(:article, created_by: @recipient)
    sign_in_as(@recipient)
  end

  test "index requires login" do
    delete session_url
    get notifications_url
    assert_redirected_to new_session_url
  end

  test "index renders newest first, marks notifications newer than the previous watermark, and clears the badge" do
    @recipient.update_column(:notifications_seen_at, 1.hour.ago)
    Notification.create!(recipient: @recipient, actor: @actor, kind: "like", subject: @article, created_at: 2.hours.ago)
    Notification.create!(recipient: @recipient, actor: @actor, kind: "comment", subject: create(:comment, commentable: @article), created_at: 30.minutes.ago)

    get root_url
    assert_select ".topbar__notifications .badge", text: "1"

    get notifications_url
    assert_response :success
    assert_select "ul.timeline > li", count: 2
    assert_select "ul.timeline > li:first-child", text: /コメントしました/
    assert_select "ul.timeline > li.notification--unread", count: 1, text: /コメントしました/
    assert_operator @recipient.reload.notifications_seen_at, :>, 1.minute.ago

    get root_url
    assert_select ".topbar__notifications .badge", count: 0
  end

  test "index shows fifty notifications and provides a cursor for older ones" do
    51.times do |i|
      Notification.create!(recipient: @recipient, actor: @actor, kind: "like", subject: @article, created_at: i.minutes.ago)
    end

    get notifications_url
    assert_select "ul.timeline > li", count: 50
    assert_select "a[href*='before=']", text: "もっと見る"
  end
end
