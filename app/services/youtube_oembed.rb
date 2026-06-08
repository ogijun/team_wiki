require "net/http"
require "json"

# YouTube はサーバからの og:title スクレイピングが consent ゲート等で不安定なため、
# 公式 oEmbed（固定ホスト www.youtube.com）から動画タイトルを取る。
# YouTube 以外の URL は nil（呼び出し側が og:title へフォールバック）。
# 取得先ホストは固定なので SSRF 面のリスクは小さい。
module YoutubeOembed
  module_function

  TIMEOUT = 3
  USER_AGENT = "team_wiki-link-preview/1.0"

  # url -> 動画タイトル or nil（YouTube でなければ取得せず nil）
  def title(url)
    id = MaterialEmbed.youtube_id(url)
    return nil unless id
    extract_title(fetch(id))
  rescue StandardError
    nil
  end

  # oEmbed JSON 文字列からタイトルを取り出す純粋関数（テスト容易）。
  def extract_title(json)
    return nil if json.to_s.strip.empty?
    title = JSON.parse(json)["title"].to_s.strip
    title.empty? ? nil : title.truncate(255)
  rescue JSON::ParserError
    nil
  end

  # 抽出した動画 id から正規の watch URL を組み立て、oEmbed を叩く（任意の生 URL は渡さない）。
  def fetch(id)
    watch = "https://www.youtube.com/watch?v=#{id}"
    uri = URI("https://www.youtube.com/oembed?" + URI.encode_www_form(url: watch, format: "json"))
    res = Net::HTTP.start(uri.host, uri.port, use_ssl: true,
                          open_timeout: TIMEOUT, read_timeout: TIMEOUT) do |http|
      req = Net::HTTP::Get.new(uri)
      req["User-Agent"] = USER_AGENT
      http.request(req)
    end
    res.is_a?(Net::HTTPSuccess) ? res.body : nil
  rescue StandardError
    nil
  end
end
