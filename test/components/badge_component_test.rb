require "test_helper"
require "view_component/test_case"

class BadgeComponentTest < ViewComponent::TestCase
  test "default variant renders plain badge" do
    html = render_inline(BadgeComponent.new(text: "編集")).to_html
    assert_includes html, "編集"
    assert_match(/class="badge"/, html)
  end

  test "status variant adds badge-status" do
    html = render_inline(BadgeComponent.new(text: "完成", variant: :status)).to_html
    assert_match(/class="badge badge-status"/, html)
    assert_includes html, "完成"
  end

  test "kind variant adds badge-kind" do
    html = render_inline(BadgeComponent.new(text: "作品", variant: :kind)).to_html
    assert_match(/class="badge badge-kind"/, html)
  end
end
