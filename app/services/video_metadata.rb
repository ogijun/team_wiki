require "net/http"
require "json"

# 動画サイトの公開 API から動画メタデータ（タイトル・公開日）を取る。
#   YouTube     = oEmbed（タイトルのみ。日付は Data API キーが要るため対象外）
#   Dailymotion = 公開 REST API（title + created_time）
#   Vimeo       = oEmbed（title + upload_date）
# 対応外の URL は nil（呼び出し側が og:title へフォールバック）。
# URL から抽出した ID で正規 URL を組み立て、固定ホストだけを叩く
# （任意の生 URL を外へ渡さない＝SSRF 面のリスクは小さい）。
module VideoMetadata
  module_function

  TIMEOUT = 3
  USER_AGENT = "team_wiki-link-preview/1.0"
  EMPTY = { title: nil, published_on: nil }.freeze

  # url -> { title:, published_on: } or nil（対応プロバイダでなければ取得せず nil）
  def call(url)
    endpoint = endpoint_for(url)
    return nil unless endpoint
    body = fetch(endpoint)
    endpoint.host == "api.dailymotion.com" ? parse_dailymotion(body) : parse_oembed(body)
  rescue StandardError
    nil
  end

  # url から対応プロバイダの API エンドポイント URI を組み立てる（非対応は nil）。
  def endpoint_for(url)
    if (id = MaterialEmbed.youtube_id(url))
      query_uri("https://www.youtube.com/oembed", url: "https://www.youtube.com/watch?v=#{id}", format: "json")
    elsif (id = MaterialEmbed.dailymotion_id(url))
      query_uri("https://api.dailymotion.com/video/#{id}", fields: "title,created_time")
    elsif (id = MaterialEmbed.vimeo_id(url))
      query_uri("https://vimeo.com/api/oembed.json", url: "https://vimeo.com/#{id}")
    end
  end

  def query_uri(endpoint, **params)
    URI("#{endpoint}?" + URI.encode_www_form(params))
  end

  # ── 純粋なパース関数（テスト容易）──

  # oEmbed JSON。Vimeo は upload_date ("YYYY-MM-DD HH:MM:SS") を含む。
  def parse_oembed(json)
    data = parse_json(json)
    date = data["upload_date"].to_s[/\d{4}-\d{2}-\d{2}/]
    { title: presence_title(data["title"]), published_on: date && Date.parse(date) }
  end

  # Dailymotion API JSON（created_time は epoch 秒）。
  def parse_dailymotion(json)
    data = parse_json(json)
    epoch = data["created_time"]
    { title: presence_title(data["title"]), published_on: epoch && Time.zone.at(epoch).to_date }
  end

  def parse_json(json)
    return {} if json.to_s.strip.empty?
    JSON.parse(json)
  rescue JSON::ParserError
    {}
  end

  def presence_title(value)
    title = value.to_s.strip
    title.empty? ? nil : title.truncate(255)
  end

  def fetch(uri)
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
