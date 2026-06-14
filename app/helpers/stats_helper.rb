module StatsHelper
  # 色の段階の閾値。count >= 各しきい値の数が段階(0..4)。ここを編集すれば配色のしきい値を調整できる。
  HEAT_THRESHOLDS = [ 1, 3, 6, 10 ].freeze

  def heat_level(count)
    HEAT_THRESHOLDS.count { |t| count >= t }
  end

  # GitHub風の日別アクティビティマップ。列=週・行=曜日（日曜始まり7行）。依存ゼロ。
  # 範囲は ActivityStats.range_start（最初のデータの週）〜今日。データ前の空マスは出さない。
  # labels: true で縦軸に曜日1文字（日〜土）を付ける。
  def activity_heatmap(counts_by_date, css: nil, labels: false)
    cells = (ActivityStats.range_start..Date.current).map do |d|
      n = counts_by_date[d] || 0
      tag.span("", class: "heat heat-#{heat_level(n)}", title: "#{d.strftime('%Y/%m/%d')} · #{n}件")
    end
    grid = tag.div(safe_join(cells), class: [ "heatmap", css ].compact.join(" "))
    return grid unless labels

    weekdays = tag.div(safe_join(%w[日 月 火 水 木 金 土].map { |w| tag.span(w) }), class: "heatmap__days")
    tag.div(safe_join([ weekdays, grid ]), class: "heatmap-cal")
  end

  # 草マップの色の凡例（少→多）。
  def heat_legend
    swatches = (0..4).map { |lvl| tag.span("", class: "heat heat-#{lvl}") }
    tag.span(safe_join([ tag.span("少", class: "muted"), *swatches, tag.span("多", class: "muted") ]),
             class: "heat-legend")
  end

  # 0..23時の件数を24本の縦棒に。高さは最大比。x軸（0/6/12/18/23時）とピーク件数を添える。
  def hourly_bars(counts, css: nil)
    peak = counts.max
    scale = [ peak, 1 ].max
    bars = counts.each_index.map do |h|
      tag.span("", class: "hourly__bar", style: "height: #{(counts[h].to_f / scale * 100).round}%",
                   title: "#{h}時 · #{counts[h]}件")
    end
    axis = tag.div(safe_join([ 0, 6, 12, 18, 23 ].map { |l| tag.span(l) }), class: "hourly__axis")
    caption = tag.div("最多 #{peak}件/時", class: "hourly__peak muted")
    tag.div(safe_join([ tag.div(safe_join(bars), class: "hourly__bars"), axis, caption ]),
            class: [ "hourly", css ].compact.join(" "))
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
