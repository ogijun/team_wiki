require "pdf-reader"

# 添付ファイルから機械可読メタデータを抽出する（画像=EXIF撮影日時 / PDF=Info辞書+頁数）。
# 抽出値は「候補」扱い：file_created_at はファイル由来の作成日カラムへ（書誌の発行日には触れない）、
# details はコメントに列挙して人が書誌へ転記する。失敗・非対応・無記載はすべて空を返す（raise しない）。
module MaterialMetadataExtractor
  module_function

  EMPTY = { file_created_at: nil, details: {} }.freeze

  def call(material)
    return EMPTY unless material.file.attached?

    case material.file.content_type
    when %r{\Aimage/} then from_image(material)
    when "application/pdf" then from_pdf(material)
    else EMPTY
    end
  rescue StandardError
    EMPTY
  end

  def from_image(material)
    material.file.open do |file|
      image = Vips::Image.new_from_file(file.path, access: :sequential)
      details = {}
      time = parse_exif_time(safe_get(image, "exif-ifd2-DateTimeOriginal"))
      details["撮影日時 (EXIF)"] = format_time(time) if time
      # マルチページ画像（TIFF/アニメGIF等）のページ数。単頁(1)は出さない
      pages = safe_get(image, "n-pages").to_i
      details["ページ数"] = pages.to_s if pages > 1
      { file_created_at: time, details: details }
    end
  end

  def safe_get(image, field)
    image.get(field)
  rescue Vips::Error
    nil
  end

  def from_pdf(material)
    material.file.open do |file|
      reader = PDF::Reader.new(file.path)
      info = reader.info || {}
      time = parse_pdf_time(info[:CreationDate].to_s)
      details = {}
      details["タイトル (PDF)"] = info[:Title].to_s if info[:Title].present?
      details["作成者 (PDF)"] = info[:Author].to_s if info[:Author].present?
      details["作成日 (PDF)"] = format_time(time) if time
      details["ページ数 (PDF)"] = reader.page_count.to_s if reader.page_count.to_i.positive?
      { file_created_at: time, details: details }
    end
  end

  # EXIF: "2020:03:16 10:00:00 (…)" / PDF: "D:20200316100000+09'00'"
  def parse_exif_time(value)
    m = value.to_s.match(/(\d{4}):(\d{2}):(\d{2}) (\d{2}):(\d{2})/)
    m && Time.zone.local(*m.captures.map(&:to_i))
  end

  def parse_pdf_time(value)
    m = value.match(/D:(\d{4})(\d{2})(\d{2})(\d{2})?(\d{2})?/)
    m && Time.zone.local(*m.captures.compact.map(&:to_i))
  end

  def format_time(time)
    time.strftime("%Y年%-m月%-d日 %H:%M")
  end
end
