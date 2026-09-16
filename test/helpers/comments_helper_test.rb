require "test_helper"

class CommentsHelperTest < ActionView::TestCase
  include UsersHelper

  test "renders a mention with the user's current name and profile link" do
    user = create(:user, name: "現在の名前")

    html = render_comment_body("こんにちは @[古い名前](#{user.id}) さん", [ user ])

    assert_includes html, %(href="/users/#{user.id}")
    assert_includes html, %(<a class="mention")
    assert_includes html, "@現在の名前"
    refute_includes html, "古い名前"
  end

  test "escapes comment HTML and leaves unknown mention tokens as text" do
    html = render_comment_body("<script>alert(1)</script> @[不明](999999)", [])

    assert_includes html, "&lt;script&gt;alert(1)&lt;/script&gt;"
    assert_includes html, "@[不明](999999)"
    refute_includes html, "<script>"
  end
end
