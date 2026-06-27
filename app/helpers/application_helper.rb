module ApplicationHelper
  include Pagy::Frontend

  PRECISION_RANK = { "year" => 0, "month" => 1, "day" => 2, "time" => 3 }.freeze
  PART_MIN_RANK = { year: 0, month: 1, day: 2, hour: 3, minute: 3 }.freeze

  # FuzzyDate の指定パーツ(year/month/day/hour/minute)を、その精度に達している時だけ返す。
  # 段階入力フォームで「精度が届く欄にだけ初期値を出す」ためのもの。精度未満や nil は nil。
  def fuzzy_part(fuzzy, part)
    return nil unless fuzzy && PRECISION_RANK.fetch(fuzzy.precision, -1) >= PART_MIN_RANK.fetch(part)
    fuzzy.at.public_send(part == :minute ? :min : part)
  end

  # 管理者が設定する自由記述（About 本文・共通フッタ）を、記事と同じ Markdown
  # パイプライン（[[記事名]]・[[ref:資料]] 込み）で描画する。空なら nil。
  def render_site_markdown(text)
    return if text.blank?

    MarkdownRenderer.for_wiki(text).render(text)
  end

  # ── アイコン（vendored Lucide スプライト app/assets/images/icons.svg の symbol を参照）──
  def icon(name, css: nil)
    tag.svg(class: [ "icon", css ].compact.join(" "), "aria-hidden": true) do
      tag.use(href: "#{asset_path("icons.svg")}##{name}")
    end
  end

  # アイコンのみのリンク。label は必須＝アクセシブル名(aria-label)とツールチップ(title)を必ず付ける
  # （icon() の svg は aria-hidden なので、ラベルが無いとリンク名が無音になるのを構造的に防ぐ）。
  def icon_link(name, url, label:, css: nil, **opts)
    link_to url, title: label, "aria-label": label,
                 class: [ "icon-link", css ].compact.join(" "), **opts do
      icon(name)
    end
  end

  # 一覧用のコンパクト日付（数字＋スラッシュ）。当年なら年を省いて月日だけ（例 06/14）、他年は 2025/12/08。
  def compact_date(time)
    time.strftime(time.year == Date.current.year ? "%m/%d" : "%Y/%m/%d")
  end

  # 一覧用のコンパクト日時。1年以内なら年を省いて時刻まで（例 06/20 14:30）、
  # 1年以上前は曖昧回避で年つき日付のみ（例 2024/03/15）。nil は nil。
  # 集計(maximum)由来の UTC Time も来るので in_time_zone で表示タイムゾーンに正規化する。
  def compact_time(time)
    return if time.nil?
    t = time.in_time_zone
    t > 1.year.ago ? t.strftime("%m/%d %H:%M") : t.strftime("%Y/%m/%d")
  end

  # ── フォームの必須/任意バッジ（ラベル横に置く）──
  def required_badge = tag.span("必須", class: "field-badge field-badge--req")
  def optional_badge = tag.span("任意", class: "field-badge field-badge--opt")

  # ── ブランド表示 ──
  def site_setting
    @site_setting ||= SiteSetting.instance
  end

  # アプリアイコン（正方形）から size×size の variant URL を返す。未設定なら nil。
  # favicon / apple-touch-icon を1枚の正方形画像から生成するためのもの。
  def site_icon_url(size)
    return unless site_setting.icon.attached?
    url_for(site_setting.icon.variant(resize_to_fill: [ size, size ]))
  end

  # ロゴが無いときのテキスト名: 設定 → ENV → 既定。
  def brand_name
    site_setting.brand_name.presence || ENV["APP_BRAND_NAME"].presence || "Team Wiki"
  end

  # ロゴ添付ありなら画像、無ければテキスト名を返す。
  def brand_display
    if site_setting.logo.attached?
      image_tag site_setting.logo, alt: brand_name, class: "brand-logo"
    else
      brand_name
    end
  end
end
