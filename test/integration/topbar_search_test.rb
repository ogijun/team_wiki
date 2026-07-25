require "test_helper"

class TopbarSearchTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(email_address: "tb@example.com", name: "T", provider: "discord", uid: "tb-user")
    sign_in_as(@user)
  end

  test "topbar search uses the shared details menu pattern" do
    get root_url
    assert_response :success
    assert_select "details.topbar__search[data-controller=menu]"
    assert_select ".topbar__search summary[aria-label=?]", "検索を開く"
    assert_select ".topbar__search .topbar__menu form[role=search][action=?][method=get]", search_path
    assert_select ".topbar__search input[type=search][name=q]"
  end
end
