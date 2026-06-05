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

  test "non-youtube url returns nil" do
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

  test "thumbnail_src returns nil for non-youtube or blank" do
    assert_nil MaterialEmbed.thumbnail_src("https://example.com/page")
    assert_nil MaterialEmbed.thumbnail_src(nil)
  end
end
