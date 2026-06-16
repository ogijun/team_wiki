# 曖昧精度の日時を表すステートレス値オブジェクト。
# articles の (starts_at, starts_precision) / (ends_at, ends_precision) を包む。
class FuzzyDate
  PRECISIONS = %w[year month day time].freeze

  # フォーム入力が数値でない／範囲外／暦上ありえない日付のとき投げる。
  # 呼び出し側（FuzzyDateAttributable）が捕捉して validation error に変える＝500 を避ける。
  class InvalidParts < StandardError; end

  attr_reader :at, :precision

  def initialize(at, precision)
    @at = at
    @precision = precision
  end

  # フォームのパーツから生成。year が空なら nil。
  # 埋まった一番細かい粒度を精度とし、粗い項目が空なら細かい項目は無視する。
  # 数値でない/範囲外/暦上ありえない日付は InvalidParts を投げる（呼び出し側が validation error 化）。
  def self.from_parts(year:, month:, day:, hour:, minute:)
    year = parse_part(year, "年", 1..9999)
    return nil if year.nil?

    month = parse_part(month, "月", 1..12)
    day = month && parse_part(day, "日", 1..31)
    hour = day && parse_part(hour, "時", 0..23)
    minute = hour ? (parse_part(minute, "分", 0..59) || 0) : nil

    precision =
      if hour then "time"
      elsif day then "day"
      elsif month then "month"
      else "year"
      end

    at = build_at(year, month, day, hour, minute)
    new(at, precision)
  end

  def self.wrap(at, precision)
    return nil if at.nil? || precision.nil?
    new(at, precision)
  end

  # 空なら nil。整数でなければ／範囲外なら InvalidParts（"05"/"09" の8進誤認を避けるため base 10 を明示）。
  def self.parse_part(value, name, range)
    s = value.to_s.strip
    return nil if s.empty?
    n =
      begin
        Integer(s, 10)
      rescue ArgumentError
        raise InvalidParts, "#{name}は数値で入力してください"
      end
    raise InvalidParts, "#{name}が範囲外です" unless range.cover?(n)
    n
  end

  # 範囲チェック済みでも 2/31 のような暦上ありえない組合せがある。Time.zone.local はロールオーバー
  # する場合があるので、Date.valid_date? で確定的に弾く（ArgumentError も保険で包む）。
  def self.build_at(year, month, day, hour, minute)
    m = month || 1
    d = day || 1
    raise InvalidParts, "日付が不正です" unless Date.valid_date?(year, m, d)
    Time.zone.local(year, m, d, hour || 0, minute || 0)
  rescue ArgumentError
    raise InvalidParts, "日付が不正です"
  end

  def label
    case precision
    when "year"  then "#{at.year}年"
    when "month" then "#{at.year}年#{at.month}月"
    when "day"   then "#{at.year}年#{at.month}月#{at.day}日"
    when "time"  then format("%d年%d月%d日 %02d:%02d", at.year, at.month, at.day, at.hour, at.min)
    end
  end

  # 数字＋区切りのコンパクト表記（時刻と同じ字面。一覧など省スペース向け）。精度で粒度が変わる。
  def slashes
    case precision
    when "year"  then at.year.to_s
    when "month" then format("%d/%02d", at.year, at.month)
    when "day"   then format("%d/%02d/%02d", at.year, at.month, at.day)
    when "time"  then format("%d/%02d/%02d %02d:%02d", at.year, at.month, at.day, at.hour, at.min)
    end
  end
end
