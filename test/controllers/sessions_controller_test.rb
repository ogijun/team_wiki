require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  setup { @user = User.create!(email_address: "sess@example.com", name: "Sess", provider: "discord", uid: "sess-user") }

  test "new" do
    get new_session_path
    assert_response :success
  end

  test "create signs in a guild member with the required role" do
    sign_in_as(@user)

    assert_redirected_to root_path
    assert cookies[:session_id]
  end

  test "create denies a user without the required role" do
    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:discord] = OmniAuth::AuthHash.new(
      provider: "discord", uid: @user.uid,
      info: { name: @user.name, email: @user.email_address, image: @user.avatar_url }
    )
    result = DiscordGuildMembership::Result.new(true, [ "other-role" ])
    original = DiscordGuildMembership.method(:call)
    DiscordGuildMembership.define_singleton_method(:call) { |**| result }
    begin
      get "/auth/discord/callback"
    ensure
      DiscordGuildMembership.define_singleton_method(:call, original)
    end

    assert_redirected_to new_session_path
    assert_nil cookies[:session_id].presence
  end

  test "destroy" do
    sign_in_as(@user)

    delete session_path

    assert_redirected_to new_session_path
    assert_empty cookies[:session_id]
  end

  test "maps discord admin role to admin, otherwise editor" do
    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:discord] = OmniAuth::AuthHash.new(
      provider: "discord", uid: "admin-uid",
      info: { name: "Admin", email: "admin@example.com" }
    )
    required = Rails.configuration.x.discord.required_role_id.to_s
    Rails.configuration.x.discord.admin_role_id = "admin-role-1"

    stub_membership(DiscordGuildMembership::Result.new(true, [ required, "admin-role-1" ])) do
      get "/auth/discord/callback"
    end
    assert_equal "admin", User.find_by(uid: "admin-uid").role

    stub_membership(DiscordGuildMembership::Result.new(true, [ required ])) do
      get "/auth/discord/callback"
    end
    assert_equal "editor", User.find_by(uid: "admin-uid").role
  ensure
    Rails.configuration.x.discord.admin_role_id = nil
  end
end
