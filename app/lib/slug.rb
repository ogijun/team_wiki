module Slug
  module_function

  # title 等に依存しない、安定したランダム URL トークン（小文字英数字）。
  def token(length = 8)
    SecureRandom.alphanumeric(length).downcase
  end

  # 衝突しないトークンを生成する。存在チェックは呼び出し側が block で渡すので、
  # Slug は ActiveRecord を知らないまま再試行制御だけを一箇所に持つ。
  def unique_token
    loop do
      candidate = token
      break candidate unless yield(candidate)
    end
  end

  # URL 非安全文字を区切りに、Unicode の文字/数字は保持する。日本語を消さない。
  def slugify(string)
    s = string.to_s.strip.downcase
    s = s.gsub(/[^\p{L}\p{N}]+/u, "-") # 文字・数字以外をハイフンに
    s = s.gsub(/-+/, "-").gsub(/\A-|-\z/, "")
    s.empty? ? "page" : s
  end
end
