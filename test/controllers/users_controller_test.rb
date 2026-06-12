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

  test "profile timeline omits the actor name and shows the streak line" do
    ActivityRecorder.record(actor: @user, action: "tag.created", subject_label: "主語なしタグ")
    get user_url(@user)
    # 自分のページでは「◯◯が」を繰り返さない
    assert_select ".timeline strong", count: 0
    assert_select ".timeline li", text: /\Aタグ「主語なしタグ」を作成しました/
    assert_select ".my-streak", text: /累計.*1.*日活動/m
  end

  test "members index is admin only" do
    get users_url
    assert_redirected_to root_url

    @user.update!(role: "admin")
    get users_url
    assert_response :success
    assert_select "td", text: /プロフ太郎/
  end
end
