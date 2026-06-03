require "test_helper"

class UsersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(email_address: "prof@example.com", name: "プロフ太郎", provider: "discord", uid: "usr-user")
    sign_in_as(@user)
  end

  test "show requires login" do
    delete session_url
    get user_url(@user)
    assert_redirected_to new_session_url
  end

  test "show displays name and recent activity" do
    ActivityRecorder.record(actor: @user, action: "tag.created", subject_label: "テストタグ")
    get user_url(@user)
    assert_response :success
    assert_select "h1", text: /プロフ太郎/
    assert_select "li", text: /テストタグ/
  end
end
