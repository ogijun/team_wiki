# Activity ログから日別・時間帯別の件数を、サイト全体＋リソース種類別で集計する。
# created_at は UTC 保存なので SQLite で JST('+9 hours') に丸める。2クエリ＋Ruby folding。
module ActivityStats
  module_function

  TYPES = %w[article material comment transcription tag].freeze
  JST = "+9 hours".freeze

  # 草マップの起点（直近 weeks 週ぶんを、列を週頭そろえにするため日曜始まりへ丸める）。
  def range_start(weeks)
    (Date.current - (weeks * 7 - 1)).beginning_of_week(:sunday)
  end

  # { total: { Date => count }, by_type: { "article" => { Date => count }, ... } }
  def daily_by_type(weeks: 26)
    rows = scoped(weeks).group(Arel.sql("date(created_at, '#{JST}')")).group(:action).count
    fold(rows) { |bucket| Date.parse(bucket) }
  end

  # { total: [24], by_type: { "article" => [24], ... } }（添字=0..23時）
  def hourly_by_type(weeks: 26)
    rows = scoped(weeks).group(Arel.sql("strftime('%H', created_at, '#{JST}')")).group(:action).count
    folded = fold(rows) { |bucket| bucket.to_i }
    { total: to_24(folded[:total]), by_type: folded[:by_type].transform_values { |h| to_24(h) } }
  end

  def scoped(weeks)
    Activity.where(created_at: range_start(weeks).beginning_of_day..)
  end

  # rows = { [bucket, action] => n } を total と種類別に畳む。bucket はブロックで正規化。
  def fold(rows)
    total = Hash.new(0)
    by_type = TYPES.index_with { Hash.new(0) }
    rows.each do |(bucket, action), n|
      key = yield(bucket)
      total[key] += n
      type = action.split(".").first
      by_type[type][key] += n if by_type.key?(type)
    end
    { total: total, by_type: by_type }
  end

  def to_24(hash)
    Array.new(24) { |h| hash[h] || 0 }
  end
end
