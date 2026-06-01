require "test_helper"

class WikiLinkExtractorTest < ActiveSupport::TestCase
  test "extracts single link" do
    assert_equal ["相互リンク"], WikiLinkExtractor.call("これは [[相互リンク]] です")
  end

  test "extracts multiple and dedups, preserving order" do
    text = "[[A]] and [[B]] and [[A]]"
    assert_equal ["A", "B"], WikiLinkExtractor.call(text)
  end

  test "trims whitespace inside brackets" do
    assert_equal ["Page Name"], WikiLinkExtractor.call("[[  Page Name  ]]")
  end

  test "ignores empty brackets" do
    assert_equal [], WikiLinkExtractor.call("[[]] と [[   ]]")
  end

  test "returns empty for no links" do
    assert_equal [], WikiLinkExtractor.call("リンクなし")
  end
end
