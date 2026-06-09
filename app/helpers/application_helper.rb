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

    MarkdownRenderer.new(
      link_resolver: WikiLinkResolver.resolver_for(text),
      ref_resolver: ->(handle) { Material.find_by(slug: handle) }
    ).render(text)
  end

  # ── フォームの必須/任意バッジ（ラベル横に置く）──
  def required_badge = tag.span("必須", class: "field-badge field-badge--req")
  def optional_badge = tag.span("任意", class: "field-badge field-badge--opt")

  # 記事一覧の小さなメタ行（状態・種別 / 更新日 ・💬件数）を組み立てる。
  def article_meta(article)
    kind = "・#{article.kind_label}" if article.kind
    comments = " ・💬#{article.comments_count}" if article.comments_count.positive?
    "#{article.status_label}#{kind} / #{article.updated_at.to_date.to_fs(:jp)}#{comments}"
  end

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
