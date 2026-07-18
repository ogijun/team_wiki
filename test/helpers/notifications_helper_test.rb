require "test_helper"

class NotificationsHelperTest < ActionView::TestCase
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
end
