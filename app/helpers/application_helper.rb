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

  # ── ブランド表示 ──
  def site_setting
    @site_setting ||= SiteSetting.instance
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
