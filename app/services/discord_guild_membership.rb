require "net/http"

# Discord の「指定ギルドにおける自分のメンバー情報」を取得し、所属とロールを返す。
module DiscordGuildMembership
  Result = Struct.new(:member, :role_ids) do
    def member? = member
  end

  module_function

  # access token で /users/@me/guilds/{guild_id}/member を叩く
  def call(token:, guild_id:)
    uri = URI("https://discord.com/api/users/@me/guilds/#{guild_id}/member")
    req = Net::HTTP::Get.new(uri)
    req["Authorization"] = "Bearer #{token}"
    res = Net::HTTP.start(uri.host, uri.port, use_ssl: true) { |http| http.request(req) }
    from_response(res)
  end

  # レスポンス（code/body を持つ）から Result を作る（テスト用に分離）
  def from_response(res)
    return Result.new(false, []) unless res.code.to_s == "200"
    data = JSON.parse(res.body)
    Result.new(true, Array(data["roles"]))
  rescue JSON::ParserError
    Result.new(false, [])
  end
end
