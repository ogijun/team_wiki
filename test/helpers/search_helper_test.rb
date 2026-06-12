require "test_helper"

class SearchHelperTest < ActionView::TestCase
  test "extracts context around the first match with ellipses" do
    text = "あ" * 100 + "キーワード" + "う" * 100
    html = search_snippet(text, "キーワード", radius: 20)
    assert_includes html, "<mark>キーワード</mark>"
    assert html.start_with?("…")
    assert html.end_with?("…")
    assert_not_includes html, "あ" * 30 # 文脈外は含まない
  end

  test "marks every match inside the window" do
    html = search_snippet("AキーワードBキーワードC", "キーワード", radius: 40)
    assert_equal 2, html.scan("<mark>").size
  end

  test "no ellipsis at text boundaries and matching is case-insensitive" do
    html = search_snippet("Ruby is fun", "ruby", radius: 40)
    assert html.start_with?("<mark>")
    assert_not html.end_with?("…")
  end

  test "returns nil when no match or blank input" do
    assert_nil search_snippet("本文", "無関係")
    assert_nil search_snippet(nil, "x")
    assert_nil search_snippet("本文", "")
  end

  test "escapes html in the surrounding text" do
    html = search_snippet("<b>怪しい</b> キーワード", "キーワード")
    assert_not_includes html, "<b>"
    assert_includes html, "<mark>キーワード</mark>"
  end
end
