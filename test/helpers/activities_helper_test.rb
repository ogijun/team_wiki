require "test_helper"

class ActivitiesHelperTest < ActionView::TestCase
  setup do
    @user = User.create!(email_address: "h@example.com", password: "password123", name: "Hana")
  end

  test "phrase for article.created includes label" do
    a = Activity.new(user: @user, action: "article.created", subject_label: "ホーム")
    assert_equal "が記事「ホーム」を作成しました", activity_phrase(a)
  end

  test "phrase for user.joined has no label" do
    a = Activity.new(user: @user, action: "user.joined")
    assert_equal "が参加しました", activity_phrase(a)
  end

  test "phrase for article.created with nil label omits label" do
    a = Activity.new(user: @user, action: "article.created", subject_label: nil)
    assert_equal "が記事を作成しました", activity_phrase(a)
  end

  # action の追加時に表示文言の追加を忘れると沈黙の汎用フォールバックに落ちるのを防ぐ。
  test "every Activity action has a display phrase" do
    assert_equal Activity::ACTIONS.sort, ActivitiesHelper::PHRASES.keys.sort
  end
end
