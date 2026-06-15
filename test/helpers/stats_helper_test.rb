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

  test "activity_heatmap with labels adds 7 single-char weekday labels" do
    travel_to Time.zone.local(2026, 6, 14, 12, 0) do
      doc = Nokogiri::HTML(activity_heatmap({}, labels: true))
      assert_equal %w[日 月 火 水 木 金 土], doc.css(".heatmap__days span").map(&:text)
    end
  end

  test "hourly_bars renders 24 bars, an axis and a peak caption" do
    html = hourly_bars(Array.new(24, 0).tap { |a| a[7] = 5 })
    doc = Nokogiri::HTML(html)
    assert_equal 24, doc.css(".hourly__bar").size
    assert doc.at_css(".hourly__axis"), "x軸ラベルがある"
    assert_match(/最多 5/, doc.at_css(".hourly__peak").text)
  end

  test "trend_bars renders one 0-baseline bar per point with y-axis max/0 and x-axis dates" do
    series = [ [ Date.new(2026, 6, 1), 0 ], [ Date.new(2026, 6, 2), 5 ], [ Date.new(2026, 6, 3), 10 ] ]
    doc = Nokogiri::HTML(trend_bars(series))
    bars = doc.css(".trend__bar")
    assert_equal 3, bars.size
    # 0基準: 値0→高さ0%、値=最大→100%、その間は比例
    assert_includes bars[0]["style"], "height: 0%"
    assert_includes bars[1]["style"], "height: 50%"
    assert_includes bars[2]["style"], "height: 100%"
    # y軸に最大値と 0
    yaxis = doc.at_css(".trend__yaxis").text
    assert_includes yaxis, "10"
    assert_includes yaxis, "0"
    # x軸に最初と最後の日付
    xaxis = doc.at_css(".trend__xaxis").text
    assert_includes xaxis, "6/1"
    assert_includes xaxis, "6/3"
  end

  test "trend_bars formats the y-axis max as a human size for :bytes" do
    series = [ [ Date.new(2026, 6, 1), 1024 ], [ Date.new(2026, 6, 2), 1_048_576 ] ]
    doc = Nokogiri::HTML(trend_bars(series, format: :bytes))
    assert_match(/MB|KB/, doc.at_css(".trend__yaxis").text)
  end
end
