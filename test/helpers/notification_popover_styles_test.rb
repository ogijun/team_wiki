require "test_helper"

class NotificationPopoverStylesTest < ActiveSupport::TestCase
  test "small screens anchor the notice popover to the viewport" do
    css = Rails.root.join("app/assets/stylesheets/base.css").read

    assert_includes css, "@media (max-width: 480px)"
    assert_includes css, ".topbar__notifications-menu"
    assert_includes css, "position: fixed;"
    assert_includes css, "left: 0.5rem;"
    assert_includes css, "right: 0.5rem;"
  end

  test "notice popover does not clamp notification text" do
    css = Rails.root.join("app/assets/stylesheets/base.css").read

    refute_includes css, "-webkit-line-clamp"
  end

  test "notice links remain inline inside notification text" do
    css = Rails.root.join("app/assets/stylesheets/base.css").read

    assert_includes css, ".topbar__notifications-menu .timeline__body a { display: inline; width: auto; }"
  end
end
