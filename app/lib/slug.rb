module Slug
  module_function

  # URL 非安全文字を区切りに、Unicode の文字/数字は保持する。日本語を消さない。
  def slugify(string)
    s = string.to_s.strip.downcase
    s = s.gsub(/[^\p{L}\p{N}]+/u, "-") # 文字・数字以外をハイフンに
    s = s.gsub(/-+/, "-").gsub(/\A-|-\z/, "")
    s.empty? ? "page" : s
  end
end
