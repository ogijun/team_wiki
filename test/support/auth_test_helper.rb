module AuthTestHelper
  # Discord ログインを OmniAuth モック + メンバーシップ service スタブで実行する。
  def sign_in_as(user)
    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:discord] = OmniAuth::AuthHash.new(
      provider: "discord", uid: user.uid,
      info: { name: user.name, email: user.email_address, image: user.avatar_url }
    )
    role = Rails.configuration.x.discord.required_role_id.to_s
    result = DiscordGuildMembership::Result.new(true, [ role ])
    stub_membership(result) do
      get "/auth/discord/callback"
    end
  end

  # DiscordGuildMembership.call を一時的に差し替える（minitest/mock 非依存）。
  def stub_membership(result)
    original = DiscordGuildMembership.method(:call)
    DiscordGuildMembership.define_singleton_method(:call) { |**| result }
    yield
  ensure
    DiscordGuildMembership.define_singleton_method(:call, original)
  end
end
