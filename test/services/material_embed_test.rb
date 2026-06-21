require "test_helper"

class MaterialEmbedTest < ActiveSupport::TestCase
  test "watch url returns youtube embed src" do
    assert_equal "https://www.youtube.com/embed/dQw4w9WgXcQ",
                 MaterialEmbed.embed_src("https://www.youtube.com/watch?v=dQw4w9WgXcQ")
  end

  test "short url returns youtube embed src" do
    assert_equal "https://www.youtube.com/embed/dQw4w9WgXcQ",
                 MaterialEmbed.embed_src("https://youtu.be/dQw4w9WgXcQ")
  end

  test "embed url returns youtube embed src" do
    assert_equal "https://www.youtube.com/embed/dQw4w9WgXcQ",
                 MaterialEmbed.embed_src("https://www.youtube.com/embed/dQw4w9WgXcQ")
  end

  test "dailymotion urls return dailymotion embed src" do
    assert_equal "https://www.dailymotion.com/embed/video/xualzi",
                 MaterialEmbed.embed_src("https://www.dailymotion.com/video/xualzi")
    assert_equal "https://www.dailymotion.com/embed/video/xualzi",
                 MaterialEmbed.embed_src("https://dai.ly/xualzi")
  end

  test "vimeo urls return vimeo player src" do
    assert_equal "https://player.vimeo.com/video/838983799",
                 MaterialEmbed.embed_src("https://vimeo.com/838983799")
    assert_equal "https://player.vimeo.com/video/838983799",
                 MaterialEmbed.embed_src("https://player.vimeo.com/video/838983799")
  end

  test "nicovideo watch and nico.ms urls return the nicovideo embed src" do
    assert_equal "https://embed.nicovideo.jp/watch/sm26015113",
                 MaterialEmbed.embed_src("https://www.nicovideo.jp/watch/sm26015113")
    assert_equal "https://embed.nicovideo.jp/watch/sm26015113",
                 MaterialEmbed.embed_src("https://nico.ms/sm26015113")
  end

  test "spotify urls return spotify embed src (type-aware)" do
    assert_equal "https://open.spotify.com/embed/episode/abc123XYZ",
                 MaterialEmbed.embed_src("https://open.spotify.com/episode/abc123XYZ?si=x")
    assert_equal "https://open.spotify.com/embed/track/0Track9Id",
                 MaterialEmbed.spotify_embed("https://open.spotify.com/intl-ja/track/0Track9Id")
    assert_nil MaterialEmbed.spotify_embed("https://example.com/page")
  end

  test "unsupported video host returns nil" do
    assert_nil MaterialEmbed.embed_src("https://example.com/page")
  end

  test "provider_for classifies the embeddable providers and returns nil otherwise" do
    assert_equal :youtube, MaterialEmbed.provider_for("https://youtu.be/dQw4w9WgXcQ")
    assert_equal :vimeo, MaterialEmbed.provider_for("https://vimeo.com/838983799")
    assert_equal :dailymotion, MaterialEmbed.provider_for("https://dai.ly/xualzi")
    assert_equal :nicovideo, MaterialEmbed.provider_for("https://www.nicovideo.jp/watch/sm26015113")
    assert_equal :spotify, MaterialEmbed.provider_for("https://open.spotify.com/episode/abc123")
    assert_nil MaterialEmbed.provider_for("https://example.com/page")
  end

  test "blank returns nil" do
    assert_nil MaterialEmbed.embed_src(nil)
    assert_nil MaterialEmbed.embed_src("")
  end

  test "thumbnail_src returns youtube thumbnail image url" do
    assert_equal "https://img.youtube.com/vi/dQw4w9WgXcQ/hqdefault.jpg",
                 MaterialEmbed.thumbnail_src("https://youtu.be/dQw4w9WgXcQ")
    assert_equal "https://img.youtube.com/vi/dQw4w9WgXcQ/hqdefault.jpg",
                 MaterialEmbed.thumbnail_src("https://www.youtube.com/watch?v=dQw4w9WgXcQ")
  end

  test "thumbnail_src returns the dailymotion thumbnail redirect url" do
    assert_equal "https://www.dailymotion.com/thumbnail/video/xualzi",
                 MaterialEmbed.thumbnail_src("https://www.dailymotion.com/video/xualzi")
  end

  test "thumbnail_src is nil for vimeo (no static url; icon fallback)" do
    assert_nil MaterialEmbed.thumbnail_src("https://vimeo.com/838983799")
  end

  test "thumbnail_src returns nil for unsupported hosts or blank" do
    assert_nil MaterialEmbed.thumbnail_src("https://example.com/page")
    assert_nil MaterialEmbed.thumbnail_src(nil)
  end
end
