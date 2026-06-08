require "test_helper"

class YoutubeOembedTest < ActiveSupport::TestCase
  test "extract_title pulls title from oEmbed JSON" do
    assert_equal "曲名 - Artist", YoutubeOembed.extract_title('{"title":"曲名 - Artist","author_name":"x"}')
  end

  test "extract_title returns nil on empty/invalid/missing-title json" do
    assert_nil YoutubeOembed.extract_title("")
    assert_nil YoutubeOembed.extract_title("not json")
    assert_nil YoutubeOembed.extract_title('{"author_name":"x"}')
  end

  test "title returns nil for non-youtube urls without fetching" do
    assert_nil YoutubeOembed.title("https://example.com/watch?v=abcdefghijk")
    assert_nil YoutubeOembed.title("not a url")
    assert_nil YoutubeOembed.title("")
  end
end
