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
    Activity.record(actor: @user, action: "tag.created", subject_label: "テストタグ")
    get user_url(@user)
    assert_response :success
    assert_select "h1", text: /プロフ太郎/
    assert_select "li", text: /テストタグ/
  end

  test "profile timeline omits the actor name and shows the streak line" do
    Activity.record(actor: @user, action: "tag.created", subject_label: "主語なしタグ")
    get user_url(@user)
    # 自分のページでは「◯◯が」を繰り返さない
    assert_select ".timeline strong", count: 0
    assert_select ".timeline li", text: /\Aタグ「主語なしタグ」を作成しました/
    assert_select ".page-meta", text: /累計.*1.*日活動/m
  end

  test "profile shows contribution counts" do
    article = Article.create!(title: "貢献記事", created_by: @user)
    article.revise!(body: "本文", author: @user)
    get user_url(@user)
    assert_select ".page-meta", text: /記事.*1.*本作成/m
    assert_select ".page-meta", text: /編集.*1.*回/m
    assert_select ".page-meta", text: /文字起こし.*0.*件/m
  end

  test "own profile links to account settings; sidebar name links to the public profile" do
    get user_url(@user)
    assert_select ".actions a[href=?]", edit_account_path
    assert_select ".sidebar__user a[href=?]", user_path(@user)
    assert_select ".sidebar__user a[href=?] svg use[href*=settings]", edit_account_path

    other = User.create!(email_address: "oth@example.com", name: "他人", provider: "discord", uid: "oth-u")
    get user_url(other)
    assert_select ".actions a[href=?]", edit_account_path, count: 0
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
