# 外部リンク URL を埋め込み/サムネ用に解決する。
# YouTube ID 抽出を共有し、embed src とサムネ画像 URL の両方を返す。
module MaterialEmbed
  module_function

  YOUTUBE_ID = %r{(?:youtube\.com/watch\?v=|youtu\.be/|youtube\.com/embed/)([\w-]{11})}

  def youtube_id(url)
    url.to_s[YOUTUBE_ID, 1]
  end

  def embed_src(url)
    id = youtube_id(url)
    id && "https://www.youtube.com/embed/#{id}"
  end

  def thumbnail_src(url)
    id = youtube_id(url)
    id && "https://img.youtube.com/vi/#{id}/hqdefault.jpg"
  end
end
