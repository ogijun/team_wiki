require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  setup { @user = User.take }

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
    result = DiscordGuildMembership::Result.new(true, ["other-role"])
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
end
