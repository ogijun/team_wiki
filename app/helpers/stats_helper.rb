module StatsHelper
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
