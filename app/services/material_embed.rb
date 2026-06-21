# 外部リンク URL を埋め込み/サムネ用に解決する（YouTube / Dailymotion / Vimeo / ニコニコ動画 / Spotify）。
# 動画 ID 抽出を共有し、embed src とサムネ画像 URL の両方を返す。HTTP は行わない。
module MaterialEmbed
  module_function

  YOUTUBE_ID = %r{(?:youtube\.com/watch\?v=|youtu\.be/|youtube\.com/embed/)([\w-]{11})}
  DAILYMOTION_ID = %r{(?:dailymotion\.com/(?:embed/)?video/|dai\.ly/)([a-zA-Z0-9]+)}
  VIMEO_ID = %r{(?:player\.)?vimeo\.com/(?:video/)?(\d+)}
  # ニコニコ動画: watch/sm******** や nico.ms 短縮。ID は sm/nm/so 接頭辞＋数字、または数字のみ。
  NICOVIDEO_ID = %r{(?:nicovideo\.jp/watch/|nico\.ms/)([a-z]{2}\d+|\d+)}
  # Spotify: track/episode/show/album/playlist/artist（intl-xx ロケール接頭辞も許容）。
  SPOTIFY = %r{open\.spotify\.com/(?:intl-\w+/)?(track|episode|show|album|playlist|artist)/([A-Za-z0-9]+)}

  def youtube_id(url) = url.to_s[YOUTUBE_ID, 1]
  def dailymotion_id(url) = url.to_s[DAILYMOTION_ID, 1]
  def vimeo_id(url) = url.to_s[VIMEO_ID, 1]
  def nicovideo_id(url) = url.to_s[NICOVIDEO_ID, 1]

  # Spotify は type ごとに embed パスが変わるので type+id を解決して embed URL を組む。
  def spotify_embed(url)
    return unless (m = url.to_s.match(SPOTIFY))
    "https://open.spotify.com/embed/#{m[1]}/#{m[2]}"
  end

  # URL がどの埋め込みプロバイダか（分類の自動推定などの判定に。embed URL の戻り形に依存させない）。
  def provider_for(url)
    return :youtube if youtube_id(url)
    return :vimeo if vimeo_id(url)
    return :dailymotion if dailymotion_id(url)
    return :nicovideo if nicovideo_id(url)
    return :spotify if url.to_s.match?(SPOTIFY)
    nil
  end

  def embed_src(url)
    if (id = youtube_id(url))
      "https://www.youtube.com/embed/#{id}"
    elsif (id = dailymotion_id(url))
      "https://www.dailymotion.com/embed/video/#{id}"
    elsif (id = vimeo_id(url))
      "https://player.vimeo.com/video/#{id}"
    elsif (id = nicovideo_id(url))
      "https://embed.nicovideo.jp/watch/#{id}"
    else
      spotify_embed(url)
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
