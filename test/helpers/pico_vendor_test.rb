require "test_helper"

class PicoVendorTest < ActiveSupport::TestCase
  test "the vendored Pico stylesheet retains its version and MIT license header" do
    css = Rails.root.join("app/assets/stylesheets/pico.classless.min.css").read

    assert_includes css, "Pico CSS ✨ v2.1.1"
    assert_includes css, "Licensed under MIT"
  end
end
