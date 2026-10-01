require "strscan"

# 利用者の入力を FTS5 の MATCH 式に「翻訳」する。入力文字列をそのまま FTS5 に渡すことは絶対にしない。
# 受け付ける構文は3つだけ: 空白区切り=AND / "…"=フレーズ / 先頭 - =除外。それ以外の記号は通常文字。
# trigram トークナイザは3文字未満の語に当たらないので、短い語は short_* に分けて呼び出し側が LIKE で補う。
class SearchQuery
  MIN_TRIGRAM = 3

  attr_reader :terms, :phrases, :excludes, :short_terms, :short_excludes

  def self.parse(raw)
    new(raw.to_s)
  end

  def initialize(raw)
    @terms = []
    @phrases = []
    @excludes = []
    @short_terms = []
    @short_excludes = []
    tokenize(raw).each { |negated, phrase, text| classify(negated, phrase, SearchNormalizer.call(text)) }
  end

  def blank? = terms.empty? && phrases.empty? && excludes.empty? && short_terms.empty? && short_excludes.empty?
  def fts? = terms.any? || phrases.any?

  # 同義語辞書の差し込み口。今回は恒等。
  def expand(term) = [ term ]

  def to_fts5
    return "" unless fts?

    positive = (terms + phrases).map { |term| quote(term) }.join(" AND ")
    negative = excludes.map { |term| " NOT #{quote(term)}" }.join
    positive + negative
  end

  private

  # => [[negated, phrase?, text], ...]
  def tokenize(raw)
    tokens = []
    scanner = StringScanner.new(raw)
    until scanner.eos?
      scanner.skip(/\s+/)
      break if scanner.eos?

      negated = scanner.skip(/-/) ? true : false
      if scanner.scan(/"([^"]*)"/)
        tokens << [ negated, true, scanner[1] ]
      elsif scanner.scan(/"?(\S+)/)
        tokens << [ negated, false, scanner[1].delete_prefix('"') ]
      end
    end
    tokens.reject { |_, _, text| text.strip.empty? }
  end

  def classify(negated, phrase, text)
    return if text.empty?

    short = text.length < MIN_TRIGRAM
    if negated
      (short ? @short_excludes : @excludes) << text
    elsif phrase && !short
      @phrases << text
    else
      (short ? @short_terms : @terms) << text
    end
  end

  def quote(text) = %("#{text.gsub('"', '""')}")
end
