require "net/http"
require "resolv"
require "ipaddr"

# 与えられた URL から og:title（無ければ <title>）を取得する。
# 任意 URL をサーバが取りに行くため SSRF を強く意識する:
#   - http/https かつ 80/443 のみ
#   - ホスト名は一度だけ解決し、解決した IP がプライベート/ループバック/リンクローカル等なら拒否
#   - 検証した IP に直結（Net::HTTP#ipaddr=）して resolve→connect の隙間(DNSリバインディング)を塞ぐ。
#     TLS の SNI/証明書検証は元ホスト名のまま行われる。
#   - リダイレクト各ホップで再検証、上限あり
#   - 本文はストリームで上限バイトまでで打ち切り、HTML のみ解析
# 取得できなければ nil（呼び出し側はフォールバック）。
module OgTitleFetcher
  module_function

  MAX_REDIRECTS = 3
  TIMEOUT = 3 # 秒（open/read 各）
  MAX_BYTES = 512 * 1024
  USER_AGENT = "team_wiki-link-preview/1.0"
  ALLOWED_PORTS = [ 80, 443 ].freeze

  # 内部/予約レンジ（IPv4/IPv6）。ここに解決される URL は取得しない。
  BLOCKED_RANGES = [
    "0.0.0.0/8", "10.0.0.0/8", "100.64.0.0/10", "127.0.0.0/8", "169.254.0.0/16",
    "172.16.0.0/12", "192.0.0.0/24", "192.168.0.0/16", "198.18.0.0/15", "224.0.0.0/4",
    "::1/128", "fc00::/7", "fe80::/10", "ff00::/8"
  ].map { |r| IPAddr.new(r) }.freeze

  # url -> タイトル文字列 or nil
  def call(url)
    uri = parse(url)
    redirects = 0
    while uri
      ip = safe_address(uri)
      return nil unless ip

      result = fetch(uri, ip)
      return nil unless result
      if result[:redirect]
        redirects += 1
        return nil if redirects > MAX_REDIRECTS
        uri = parse(URI.join(uri.to_s, result[:redirect]).to_s)
        next
      end
      return result[:title]
    end
    nil
  rescue StandardError
    nil
  end

  # HTML から og:title（優先）/ <title> を取り出す純粋関数（テスト容易）。
  def extract_title(html)
    doc = Nokogiri::HTML(html.to_s.byteslice(0, MAX_BYTES).to_s)
    og = doc.at('meta[property="og:title"]')&.[]("content")
    title = og.presence || doc.at("title")&.text
    title = title.to_s.strip
    title.empty? ? nil : title.truncate(255)
  end

  def parse(url)
    uri = URI.parse(url.to_s)
    uri.is_a?(URI::HTTP) ? uri : nil
  rescue URI::InvalidURIError
    nil
  end

  # scheme/port/解決先 IP を検証し、接続に使う「安全な IP」を返す。危険なら nil。
  def safe_address(uri)
    return nil unless %w[http https].include?(uri.scheme)
    return nil unless ALLOWED_PORTS.include?(uri.port)
    host = uri.host.to_s
    return nil if host.empty?

    if (literal = ip_literal(host))
      return blocked_ip?(literal) ? nil : literal
    end

    addrs = Resolv.getaddresses(host)
    return nil if addrs.empty? || addrs.any? { |a| blocked_ip?(a) }
    addrs.first
  rescue StandardError
    nil
  end

  def ip_literal(host)
    IPAddr.new(host).to_s
  rescue IPAddr::InvalidAddressError
    nil
  end

  def blocked_ip?(addr)
    ip = IPAddr.new(addr)
    BLOCKED_RANGES.any? { |range| range.include?(ip) }
  rescue StandardError
    true # 解釈できないものは安全側で拒否
  end

  # 検証済み ip に直結して取得。{ redirect: location } か { title: ... } を返す。
  def fetch(uri, ip)
    http = Net::HTTP.new(uri.host, uri.port) # ホスト名は SNI/証明書検証に使う
    http.ipaddr = ip                          # 実際の接続先は検証済み IP に固定
    http.use_ssl = (uri.scheme == "https")
    http.open_timeout = TIMEOUT
    http.read_timeout = TIMEOUT

    http.start do
      req = Net::HTTP::Get.new(uri)
      req["User-Agent"] = USER_AGENT
      req["Accept"] = "text/html,application/xhtml+xml"

      http.request(req) do |res|
        return { redirect: res["location"] } if res.is_a?(Net::HTTPRedirection) && res["location"].present?
        return nil unless res.is_a?(Net::HTTPSuccess)
        return nil unless res.content_type.to_s.include?("html")

        body = +""
        res.read_body do |chunk|
          body << chunk
          break if body.bytesize >= MAX_BYTES
        end
        return { title: extract_title(body) }
      end
    end
  rescue StandardError
    nil
  end
end
