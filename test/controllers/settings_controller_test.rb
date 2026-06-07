require "test_helper"

class SettingsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(email_address: "set@example.com", name: "S", provider: "discord", uid: "set-user")
    sign_in_as(@user)
  end

  test "edit is admin only" do
    get edit_settings_url
    assert_redirected_to root_url

    @user.update!(role: "admin")
    get edit_settings_url
    assert_response :success
  end

  test "admin updates brand name" do
    @user.update!(role: "admin")
    patch settings_url, params: { site_setting: { brand_name: "サンプルWiki" } }
    assert_equal "サンプルWiki", SiteSetting.instance.brand_name
  end

  test "admin updates about text" do
    @user.update!(role: "admin")
    patch settings_url, params: { site_setting: { brand_name: "x", about: "## ようこそ" } }
    assert_equal "## ようこそ", SiteSetting.instance.about
  end

  test "admin updates footer text" do
    @user.update!(role: "admin")
    patch settings_url, params: { site_setting: { brand_name: "x", footer: "© 2026" } }
    assert_equal "© 2026", SiteSetting.instance.footer
  end

  test "admin can remove logo (falls back to text)" do
    @user.update!(role: "admin")
    s = SiteSetting.instance
    s.logo.attach(io: StringIO.new("x"), filename: "l.png", content_type: "image/png")
    s.save!
    patch settings_url, params: { site_setting: { brand_name: "x" }, remove_logo: "1" }
    assert_not SiteSetting.instance.logo.attached?
  end
end
