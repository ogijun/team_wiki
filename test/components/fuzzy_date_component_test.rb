require "test_helper"
require "view_component/test_case"

class FuzzyDateComponentTest < ViewComponent::TestCase
  test "renders a single fuzzy date label" do
    fd = FuzzyDate.wrap(Time.zone.local(1979, 4, 7), "day")
    html = render_inline(FuzzyDateComponent.new(starts: fd)).to_html
    assert_includes html, "1979年4月7日"
  end

  test "renders a range when ends is given" do
    s = FuzzyDate.wrap(Time.zone.local(1979), "year")
    e = FuzzyDate.wrap(Time.zone.local(1980), "year")
    html = render_inline(FuzzyDateComponent.new(starts: s, ends: e)).to_html
    assert_includes html, "1979年 〜 1980年"
  end

  test "icon: true prefixes a calendar" do
    fd = FuzzyDate.wrap(Time.zone.local(1979), "year")
    html = render_inline(FuzzyDateComponent.new(starts: fd, icon: true)).to_html
    assert_includes html, "🗓"
  end

  test "renders nothing when starts is nil" do
    html = render_inline(FuzzyDateComponent.new(starts: nil)).to_html
    assert_equal "", html.strip
  end
end
