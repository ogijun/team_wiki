require "test_helper"

class HomeControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(email_address: "home@example.com", name: "H", provider: "discord", uid: "home-user")
    sign_in_as(@user)
  end

  test "requires login" do
    delete session_url
    get root_url
    assert_redirected_to new_session_url
  end

  test "shows dashboard sections" do
    Article.create!(title: "ダッシュ記事", created_by: @user, status: "stub")
    get root_url
    assert_response :success
    assert_select "h2", text: "最近更新された記事"
    assert_select "h2", text: "加筆を求む"
    assert_select "h2", text: "最近の動き"
    assert_select ".dashboard-stats"
    assert_select "a", text: /ダッシュ記事/
  end
end
