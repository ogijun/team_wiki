require "application_system_test_case"

class SignInTest < ApplicationSystemTestCase
  test "ログインしていなければログイン画面に送られる" do
    visit root_path
    assert_current_path new_session_path
    assert_button "Discord でログイン"
  end

  test "Discord でログインすると、ユーザーメニューに名前とログアウトが出る" do
    user = create(:user, name: "システムテスト太郎")
    sign_in_through_ui(user)
    open_user_menu
    assert_text "システムテスト太郎"
    assert_button "ログアウト"
  end
end
