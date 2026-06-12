# 外部リンク URL を埋め込み/サムネ用に解決する（YouTube / Dailymotion / Vimeo）。
# 動画 ID 抽出を共有し、embed src とサムネ画像 URL の両方を返す。HTTP は行わない。
module MaterialEmbed
  module_function

  YOUTUBE_ID = %r{(?:youtube\.com/watch\?v=|youtu\.be/|youtube\.com/embed/)([\w-]{11})}
  DAILYMOTION_ID = %r{(?:dailymotion\.com/(?:embed/)?video/|dai\.ly/)([a-zA-Z0-9]+)}
  VIMEO_ID = %r{(?:player\.)?vimeo\.com/(?:video/)?(\d+)}

  def youtube_id(url) = url.to_s[YOUTUBE_ID, 1]
  def dailymotion_id(url) = url.to_s[DAILYMOTION_ID, 1]
  def vimeo_id(url) = url.to_s[VIMEO_ID, 1]

  def embed_src(url)
    if (id = youtube_id(url))
      "https://www.youtube.com/embed/#{id}"
    elsif (id = dailymotion_id(url))
      "https://www.dailymotion.com/embed/video/#{id}"
    elsif (id = vimeo_id(url))
      "https://player.vimeo.com/video/#{id}"
    end
  end

  def thumbnail_src(url)
    if (id = youtube_id(url))
      "https://img.youtube.com/vi/#{id}/hqdefault.jpg"
    elsif (id = dailymotion_id(url))
      # CDN へ 301 リダイレクトされる公式サムネ URL（img src で利用可）
      "https://www.dailymotion.com/thumbnail/video/#{id}"
    end
    # Vimeo は静的サムネ URL を組めない（oEmbed が要る）ため nil ＝種別アイコンにフォールバック
  end
end
