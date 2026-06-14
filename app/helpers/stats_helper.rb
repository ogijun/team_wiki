module StatsHelper
  # 色の段階の閾値。count >= 各しきい値の数が段階(0..4)。ここを編集すれば配色のしきい値を調整できる。
  HEAT_THRESHOLDS = [ 1, 3, 6, 10 ].freeze

  def heat_level(count)
    HEAT_THRESHOLDS.count { |t| count >= t }
  end

  # GitHub風の日別アクティビティマップ。列=週・行=曜日（日曜始まり7行）。依存ゼロ。
  def activity_heatmap(counts_by_date, weeks: 26, css: nil)
    cells = (ActivityStats.range_start(weeks)..Date.current).map do |d|
      n = counts_by_date[d] || 0
      tag.span("", class: "heat heat-#{heat_level(n)}", title: "#{d.strftime('%Y/%m/%d')} · #{n}件")
    end
    tag.div(safe_join(cells), class: [ "heatmap", css ].compact.join(" "))
  end

  # 0..23時の件数を24本の縦棒に。高さは最大比。
  def hourly_bars(counts)
    max = [ counts.max, 1 ].max
    bars = counts.each_index.map do |h|
      tag.span("", class: "hourly__bar", style: "height: #{(counts[h].to_f / max * 100).round}%",
                   title: "#{h}時 · #{counts[h]}件")
    end
    tag.div(safe_join(bars), class: "hourly")
  end

  # 値の配列をスパークライン SVG にする（依存なし・サーバーサイド描画）。
  # 値1個のときは線が描けないので点を打つ。
  def sparkline_svg(values, width: 280, height: 56)
    pad = 4
    max = [ values.max, 1 ].max
    min = values.min
    range = [ max - min, 1 ].max
    points = values.each_with_index.map do |v, i|
      x = values.size == 1 ? width / 2.0 : pad + i * (width - pad * 2).to_f / (values.size - 1)
      y = height - pad - (v - min).to_f / range * (height - pad * 2)
      [ x.round(1), y.round(1) ]
    end

    content_tag(:svg, viewBox: "0 0 #{width} #{height}", class: "sparkline",
                preserveAspectRatio: "none", "aria-hidden": true) do
      if points.size == 1
        tag.circle(cx: points[0][0], cy: points[0][1], r: 3)
      else
        tag.polyline(points: points.map { |x, y| "#{x},#{y}" }.join(" "), fill: "none")
      end
    end
  end
end
