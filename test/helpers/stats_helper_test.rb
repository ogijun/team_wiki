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

  test "activity_heatmap renders one .heat cell per day in range" do
    travel_to Time.zone.local(2026, 6, 14, 12, 0) do
      html = activity_heatmap({})
      expected = (Date.current - ActivityStats.range_start(26)).to_i + 1
      assert_equal expected, Nokogiri::HTML(html).css(".heat").size
    end
  end

  test "hourly_bars renders 24 bars" do
    html = hourly_bars(Array.new(24, 0).tap { |a| a[7] = 5 })
    assert_equal 24, Nokogiri::HTML(html).css(".hourly__bar").size
  end
end
