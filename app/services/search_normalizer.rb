# 検索用の正規化。索引時と検索時の両方が必ずこれを通す（片方だけだと当たらなくなる）。
# 元テキストは索引に持たず、表示は実レコードから作るので、ここは「当たるかどうか」だけを整える。
module SearchNormalizer
  module_function

  # ー － — – 〜 ～ を長音「ー」に寄せる。ASCII の - と ~ は含めない（p.1-10 のような識別子を壊すため）。
  # NFKC は － と ～ を ASCII に落としてしまうので、NFKC より「前」に当てる。
  DASHES = /[ー－—–〜～]/

  def call(text)
    s = text.to_s.gsub(DASHES, "ー")
    s = s.unicode_normalize(:nfkc)
    s = s.tr("ぁ-ゖ", "ァ-ヶ").tr("ゔ", "ヴ")
    s = s.downcase
    s.gsub(/\s+/, " ").strip
  end
end
