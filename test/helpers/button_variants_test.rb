require "test_helper"

class ButtonVariantsTest < ActiveSupport::TestCase
  test "secondary and outline button variants are defined without Pico" do
    css = Rails.root.join("app/assets/stylesheets/components.css").read

    assert_includes css, 'a[role="button"].secondary'
    assert_includes css, "a.button.outline"
    assert_includes css, "background: transparent; border: 1px solid currentColor; color: var(--ink-soft);"
  end
end
