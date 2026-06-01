require "test_helper"

class SlugTest < ActiveSupport::TestCase
  test "ascii lowercased and spaces to hyphen" do
    assert_equal "hello-world", Slug.slugify("Hello World")
  end

  test "keeps japanese characters" do
    assert_equal "相互リンク", Slug.slugify("相互リンク")
  end

  test "japanese with spaces and symbols" do
    assert_equal "設計-メモ", Slug.slugify("設計 / メモ")
  end

  test "collapses repeated separators and trims" do
    assert_equal "a-b", Slug.slugify("  a  --  b  ")
  end

  test "blank falls back to 'page'" do
    assert_equal "page", Slug.slugify("   ")
  end
end
