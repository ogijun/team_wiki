require "test_helper"

class MembersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(email_address: "m@example.com", name: "M", provider: "discord", uid: "mem-user", bio: "書誌担当")
    sign_in_as(@user)
  end

  test "members list is visible to non-admin members" do
    get members_url
    assert_response :success
    assert_select "body", /書誌担当/
    assert_select "a[href=?]", user_path(@user)
  end

  test "members list does not leak admin columns" do
    get members_url
    assert_select "body", { text: /最終ログイン|最終アクセス/, count: 0 }
  end

  test "sidebar links everyone to members" do
    get root_url
    assert_select "nav a[href=?]", members_path, text: /メンバー/
  end

  test "guests are redirected" do
    delete session_url
    get members_url
    assert_redirected_to new_session_url
  end
end
