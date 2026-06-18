require "test_helper"

class TopbarSearchTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(email_address: "tb@example.com", name: "T", provider: "discord", uid: "tb-user")
    sign_in_as(@user)
  end

  test "topbar shows a search toggle that opens an overlay search form" do
    get root_url
    assert_response :success
    # アイコンのトグル（押すとトップバーを覆うオーバーレイで検索窓が出る）
    assert_select "[data-controller='search'] button[data-action~='search#open'][aria-label=?]", "検索を開く"
    # オーバーレイ内に検索フォーム（/search へ GET、q パラメータ）。挙動は全画面共通。
    assert_select "[data-controller='search'] form[role='search'][action=?]", search_path
    assert_select "[data-controller='search'] form[role='search'] input[type='search'][name='q']"
    # 閉じるボタン
    assert_select "[data-controller='search'] button[aria-label=?]", "検索を閉じる"
  end
end
