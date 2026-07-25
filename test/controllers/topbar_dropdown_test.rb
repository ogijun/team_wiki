require "test_helper"

class TopbarDropdownTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as(create(:user))
  end

  test "search uses the same details menu pattern as other topbar dropdowns" do
    get root_url

    assert_select "details.topbar__search[data-controller=menu]"
    assert_select ".topbar__search summary[aria-label='検索を開く']"
    assert_select ".topbar__search .topbar__menu.topbar__search-menu form[action=?][method=get]", search_path
    assert_select ".topbar__search input[type=search][name=q]"
  end
end
