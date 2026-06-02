# 外部リンク URL を埋め込み用 iframe src に解決する。
# プロバイダは PROVIDERS に追加して拡張できる（初期は YouTube のみ）。
module MaterialEmbed
  module_function

  # 各プロバイダ: URL -> 埋め込み src（非対応なら nil）を返す lambda
  PROVIDERS = [
    # YouTube: watch?v=, youtu.be/, /embed/
    ->(url) {
      id = url[%r{(?:youtube\.com/watch\?v=|youtu\.be/|youtube\.com/embed/)([\w-]{11})}, 1]
      id && "https://www.youtube.com/embed/#{id}"
    }
  ].freeze

  def embed_src(url)
    return nil if url.blank?
    PROVIDERS.lazy.filter_map { |p| p.call(url) }.first
  end
end
