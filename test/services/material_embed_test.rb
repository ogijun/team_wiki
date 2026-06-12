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

  test "unsupported video host returns nil" do
    assert_nil MaterialEmbed.embed_src("https://example.com/page")
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
