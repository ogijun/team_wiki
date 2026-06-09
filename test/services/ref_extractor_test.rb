require "test_helper"

class RefExtractorTest < ActiveSupport::TestCase
  test "extracts a single ref handle" do
    assert_equal [ "abc123" ], RefExtractor.call("主張です[[ref:abc123]]")
  end

  test "extracts multiple, dedups, preserves order" do
    assert_equal [ "a", "b" ], RefExtractor.call("[[ref:a]] と [[ref:b]] と [[ref:a]]")
  end

  test "trims whitespace and ignores empty" do
    assert_equal [ "x" ], RefExtractor.call("[[ref:  x  ]] [[ref:]]")
  end

  test "ignores plain wiki links" do
    assert_equal [], RefExtractor.call("[[記事]] にはrefなし")
  end
end
