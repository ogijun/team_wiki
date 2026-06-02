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
end
