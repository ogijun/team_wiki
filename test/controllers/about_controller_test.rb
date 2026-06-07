require "test_helper"

class AboutControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(email_address: "about@example.com", name: "A", provider: "discord", uid: "about-user")
  end

  test "requires login" do
    get about_url
    assert_redirected_to new_session_url
  end

  test "renders the about markdown" do
    SiteSetting.instance.update!(about: "# はじめに\n\nこれは **本文** です。")
    sign_in_as(@user)
    get about_url
    assert_response :success
    assert_select "h1", text: "このサイトについて"
    assert_select "strong", text: "本文"
  end

  test "shows an empty state when about is blank" do
    sign_in_as(@user)
    get about_url
    assert_response :success
    assert_select "p.muted"
  end

  test "shows an edit link only to admins" do
    SiteSetting.instance.update!(about: "x")
    sign_in_as(@user)
    get about_url
    assert_select "a[href=?]", edit_settings_path, count: 0

    @user.update!(role: "admin")
    get about_url
    assert_select "a[href=?]", edit_settings_path
  end
end
