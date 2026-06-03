Rails.application.config.x.discord.guild_id = ENV.fetch("DISCORD_GUILD_ID", "test-guild")
Rails.application.config.x.discord.required_role_id = ENV.fetch("DISCORD_REQUIRED_ROLE_ID", "test-role")

Rails.application.config.middleware.use OmniAuth::Builder do
  provider :discord,
           ENV.fetch("DISCORD_CLIENT_ID", "test-client"),
           ENV.fetch("DISCORD_CLIENT_SECRET", "test-secret"),
           scope: "identify email guilds guilds.members.read"
end

OmniAuth.config.allowed_request_methods = %i[post]
