require "test_helper"

class ActivitiesHelperTest < ActionView::TestCase
  setup do
    @user = User.create!(email_address: "h@example.com", password: "password123", name: "Hana")
  end

  test "phrase for page.created includes label" do
    a = Activity.new(user: @user, action: "page.created", subject_label: "ホーム")
    assert_equal "がページ「ホーム」を作成しました", activity_phrase(a)
  end

  test "phrase for user.joined has no label" do
    a = Activity.new(user: @user, action: "user.joined")
    assert_equal "が参加しました", activity_phrase(a)
  end

  test "phrase for unknown action falls back" do
    a = Activity.new(user: @user, action: "page.created", subject_label: nil)
    assert_equal "がページを作成しました", activity_phrase(a)
  end
end
