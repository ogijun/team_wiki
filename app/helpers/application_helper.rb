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
end
