require "test_helper"

class VideoMetadataTest < ActiveSupport::TestCase
  test "parse_oembed pulls title (and Vimeo upload_date) from oEmbed JSON" do
    meta = VideoMetadata.parse_oembed('{"title":"動画名","upload_date":"2023-06-23 06:52:11"}')
    assert_equal "動画名", meta[:title]
    assert_equal Date.new(2023, 6, 23), meta[:published_on]

    no_date = VideoMetadata.parse_oembed('{"title":"日付なし"}')
    assert_equal "日付なし", no_date[:title]
    assert_nil no_date[:published_on]
  end

  test "parse_dailymotion pulls title and created_time (epoch)" do
    meta = VideoMetadata.parse_dailymotion('{"title":"DM動画","created_time":1350105448}')
    assert_equal "DM動画", meta[:title]
    assert_equal Time.zone.at(1350105448).to_date, meta[:published_on]
  end

  test "parsers return empty meta on invalid or blank json" do
    assert_equal({ title: nil, published_on: nil }, VideoMetadata.parse_oembed("not json"))
    assert_equal({ title: nil, published_on: nil }, VideoMetadata.parse_dailymotion(""))
  end

  test "call returns nil for unsupported urls without fetching" do
    assert_nil VideoMetadata.call("https://example.com/watch?v=abcdefghijk")
    assert_nil VideoMetadata.call("not a url")
    assert_nil VideoMetadata.call("")
  end

  test "endpoint_for builds the provider api url from the extracted id" do
    assert_includes VideoMetadata.endpoint_for("https://youtu.be/dQw4w9WgXcQ").to_s,
                    "www.youtube.com/oembed"
    assert_includes VideoMetadata.endpoint_for("https://www.dailymotion.com/video/xualzi").to_s,
                    "api.dailymotion.com/video/xualzi"
    assert_includes VideoMetadata.endpoint_for("https://vimeo.com/838983799").to_s,
                    "vimeo.com/api/oembed.json"
    assert_nil VideoMetadata.endpoint_for("https://example.com/x")
  end
end
