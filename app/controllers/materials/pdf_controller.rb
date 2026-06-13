# PDF.js ビューア専用の同一オリジン配信。
# ActiveStorage 既定の proxy はフル応答が chunked（Content-Length 無し）で、PDF.js が
# Range の利用可否を判定できず全体をダウンロードしてしまう。ここではフル応答に
# Content-Length と Accept-Ranges を付け、PDF.js が範囲取得に切り替えられるようにする。
# Range 要求は ActiveStorage の既存処理（206 + Content-Range）をそのまま使う。
class Materials::PdfController < ApplicationController
  include ActiveStorage::Streaming

  before_action :set_material

  def show
    blob = @material.file.blob
    return head(:not_found) unless blob&.content_type == "application/pdf"

    if request.headers["Range"].present?
      send_blob_byte_range_data(blob, request.headers["Range"])
    else
      send_full(blob)
    end
  end

  private

  # フル応答は Content-Length 付きでストリーム配信する（メモリに載せない）。
  # PDF.js は Content-Length + Accept-Ranges を見て範囲取得を有効化し、この応答は
  # ヘッダ受信後に中断して以降は Range 要求でページ単位に取得する。
  def send_full(blob)
    response.headers["Content-Length"] = blob.byte_size.to_s
    response.headers["Accept-Ranges"] = "bytes"
    response.headers["Content-Type"] = blob.content_type_for_serving
    response.headers["Content-Disposition"] =
      ActionDispatch::Http::ContentDisposition.format(disposition: "inline", filename: blob.filename.sanitized)
    self.response_body = Enumerator.new { |y| blob.download { |chunk| y << chunk } }
  end

  def set_material
    @material = Material.find(params[:id])
  end
end
