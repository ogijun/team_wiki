require "test_helper"

class OgTitleFetcherTest < ActiveSupport::TestCase
  test "extract_title prefers og:title" do
    html = %(<html><head><meta property="og:title" content="OG タイトル"><title>doc</title></head></html>)
    assert_equal "OG タイトル", OgTitleFetcher.extract_title(html)
  end

  test "extract_title falls back to <title>" do
    assert_equal "ドキュメント", OgTitleFetcher.extract_title("<html><head><title>ドキュメント</title></head></html>")
  end

  test "extract_title returns nil without any title" do
    assert_nil OgTitleFetcher.extract_title("<html><body>no title here</body></html>")
  end

  test "call rejects non-http schemes and garbage without fetching" do
    assert_nil OgTitleFetcher.call("ftp://example.com/x")
    assert_nil OgTitleFetcher.call("not a url")
    assert_nil OgTitleFetcher.call("")
  end

  # SSRF ガード: 解決先が内部/予約レンジなら取得しない（ネットワークに出ない）。
  test "call rejects private/loopback/link-local hosts" do
    assert_nil OgTitleFetcher.call("http://127.0.0.1/x")
    assert_nil OgTitleFetcher.call("http://10.0.0.5/x")
    assert_nil OgTitleFetcher.call("http://169.254.169.254/latest/meta-data/")
    assert_nil OgTitleFetcher.call("http://192.168.1.1/x")
  end
end
