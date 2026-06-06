if Rails.env.production?
  raise "DISCORD_GUILD_ID must be set" if ENV["DISCORD_GUILD_ID"].blank?
  raise "DISCORD_REQUIRED_ROLE_ID must be set" if ENV["DISCORD_REQUIRED_ROLE_ID"].blank?
end

Rails.application.config.x.discord.guild_id = ENV.fetch("DISCORD_GUILD_ID", "test-guild")
Rails.application.config.x.discord.required_role_id = ENV.fetch("DISCORD_REQUIRED_ROLE_ID", "test-role")
Rails.application.config.x.discord.admin_role_id = ENV["DISCORD_ADMIN_ROLE_ID"]

# admin_role_id は任意（admin 不在のインスタンスもあり得る）ので raise しないが、
# 本番で未設定だと全員 editor 扱いになり、既存 admin が次回ログインで降格する。
if Rails.env.production? && ENV["DISCORD_ADMIN_ROLE_ID"].blank?
  Rails.logger.warn("[auth] DISCORD_ADMIN_ROLE_ID is unset; all users resolve to 'editor' and any existing admins are demoted on next login.")
end

Rails.application.config.middleware.use OmniAuth::Builder do
  provider :discord,
           ENV.fetch("DISCORD_CLIENT_ID", "test-client"),
           ENV.fetch("DISCORD_CLIENT_SECRET", "test-secret"),
           scope: "identify email guilds.members.read"
end

OmniAuth.config.allowed_request_methods = %i[post]

# リバースプロキシ(puma-dev等)越しで scheme/host がブレると、認可フェーズと
# トークン交換フェーズで redirect_uri が食い違い invalid_grant になる。
# APP_BASE_URL を与えたら redirect_uri を固定し、両フェーズで一致させる。
# 例: APP_BASE_URL=http://team-wiki-pre.test （Discord登録の callback と scheme/host を揃える）
OmniAuth.config.full_host = ENV["APP_BASE_URL"] if ENV["APP_BASE_URL"].present?
