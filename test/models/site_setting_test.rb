require "test_helper"

class SiteSettingTest < ActiveSupport::TestCase
  test "instance returns the single row, creating it once" do
    s1 = SiteSetting.instance
    s2 = SiteSetting.instance
    assert_equal s1.id, s2.id
    assert_equal 1, SiteSetting.count
  end

  test "rejects a non-image logo" do
    s = SiteSetting.instance
    s.logo.attach(io: StringIO.new("x"), filename: "a.txt", content_type: "text/plain")
    assert_not s.valid?
    assert_predicate s.errors[:logo], :any?
  end

  test "accepts an image logo" do
    s = SiteSetting.instance
    s.logo.attach(io: StringIO.new("x"), filename: "logo.png", content_type: "image/png")
    assert_predicate s, :valid?, s.errors.full_messages.join(", ")
  end

  test "rejects a non-image icon" do
    s = SiteSetting.instance
    s.icon.attach(io: StringIO.new("x"), filename: "a.txt", content_type: "text/plain")
    assert_not s.valid?
    assert_predicate s.errors[:icon], :any?
  end

  test "accepts an image icon" do
    s = SiteSetting.instance
    s.icon.attach(io: StringIO.new("x"), filename: "icon.png", content_type: "image/png")
    assert_predicate s, :valid?, s.errors.full_messages.join(", ")
  end

  test "blank tagline normalizes to nil (so the hero omits it)" do
    s = SiteSetting.instance
    s.update!(tagline: "   ")
    assert_nil s.reload.tagline
  end

  test "rejects an overlong tagline (it's a one-line mission, not prose)" do
    s = SiteSetting.instance
    s.tagline = "あ" * 121
    assert_not s.valid?
    assert_predicate s.errors[:tagline], :any?
  end

  test "blank home_heading normalizes to nil (so the hero falls back to sr-only)" do
    s = SiteSetting.instance
    s.update!(home_heading: "   ")
    assert_nil s.reload.home_heading
  end

  test "rejects an overlong home_heading (it's a heading, not prose)" do
    s = SiteSetting.instance
    s.home_heading = "あ" * 61
    assert_not s.valid?
    assert_predicate s.errors[:home_heading], :any?
  end
end
