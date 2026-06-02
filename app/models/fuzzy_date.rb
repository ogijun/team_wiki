# 曖昧精度の日時を表すステートレス値オブジェクト。
# articles の (starts_at, starts_precision) / (ends_at, ends_precision) を包む。
class FuzzyDate
  PRECISIONS = %w[year month day time].freeze

  attr_reader :at, :precision

  def initialize(at, precision)
    @at = at
    @precision = precision
  end

  # フォームのパーツから生成。year が空なら nil。
  # 埋まった一番細かい粒度を精度とし、粗い項目が空なら細かい項目は無視する。
  def self.from_parts(year:, month:, day:, hour:, minute:)
    year = presence_int(year)
    return nil if year.nil?

    month = presence_int(month)
    day = month && presence_int(day)
    hour = day && presence_int(hour)
    minute = hour ? (presence_int(minute) || 0) : nil

    precision =
      if hour then "time"
      elsif day then "day"
      elsif month then "month"
      else "year"
      end

    at = Time.zone.local(year, month || 1, day || 1, hour || 0, minute || 0)
    new(at, precision)
  end

  def self.wrap(at, precision)
    return nil if at.nil? || precision.nil?
    new(at, precision)
  end

  def self.presence_int(value)
    s = value.to_s.strip
    return nil if s.empty?
    s.to_i
  end

  def label
    case precision
    when "year"  then "#{at.year}年"
    when "month" then "#{at.year}年#{at.month}月"
    when "day"   then "#{at.year}年#{at.month}月#{at.day}日"
    when "time"  then format("%d年%d月%d日 %02d:%02d", at.year, at.month, at.day, at.hour, at.min)
    end
  end
end
