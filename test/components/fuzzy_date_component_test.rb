require "test_helper"
require "view_component/test_case"

class FuzzyDateComponentTest < ViewComponent::TestCase
  test "renders a single fuzzy date label" do
    html = render_inline(FuzzyDateComponent.new(starts: "1979-04-07")).to_html
    assert_includes html, "1979年4月7日"
    assert_includes html, 'datetime="1979-04-07"'
  end

  test "renders a range when ends is given" do
    fragment = render_inline(FuzzyDateComponent.new(starts: "1979", ends: "1980"))
    assert_equal "1979年 〜 1980年", fragment.text.strip
  end

  test "icon: true prefixes a calendar" do
    html = render_inline(FuzzyDateComponent.new(starts: "1979", icon: true)).to_html
    assert_includes html, "#calendar"
  end

  test "renders nothing when starts is nil" do
    html = render_inline(FuzzyDateComponent.new(starts: nil)).to_html
    assert_equal "", html.strip
  end
end
