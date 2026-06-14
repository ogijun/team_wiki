require "test_helper"

class StatsHelperTest < ActionView::TestCase
  test "heat_level maps counts to 0..4 by thresholds" do
    assert_equal 0, heat_level(0)
    assert_equal 1, heat_level(1)
    assert_equal 1, heat_level(2)
    assert_equal 2, heat_level(3)
    assert_equal 2, heat_level(5)
    assert_equal 3, heat_level(6)
    assert_equal 4, heat_level(10)
    assert_equal 4, heat_level(99)
  end

  test "activity_heatmap renders one .heat cell per day from range_start to today" do
    travel_to Time.zone.local(2026, 6, 14, 12, 0) do
      html = activity_heatmap({})
      expected = (Date.current - ActivityStats.range_start).to_i + 1
      assert_equal expected, Nokogiri::HTML(html).css(".heat").size
    end
  end

  test "heat_legend renders 5 swatches" do
    assert_equal 5, Nokogiri::HTML(heat_legend).css(".heat").size
  end

  test "hourly_bars renders 24 bars, an axis and a peak caption" do
    html = hourly_bars(Array.new(24, 0).tap { |a| a[7] = 5 })
    doc = Nokogiri::HTML(html)
    assert_equal 24, doc.css(".hourly__bar").size
    assert doc.at_css(".hourly__axis"), "x軸ラベルがある"
    assert_match(/最多 5/, doc.at_css(".hourly__peak").text)
  end
end
