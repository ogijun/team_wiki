# 全資料の文字起こし進捗ボード（資料を集約ステータスでグルーピングして表示）。
# 中身は Transcription レコードの一覧ではなく Material の進捗なので、
# パート CRUD の TranscriptionsController（material ネストの REST リソース）とは分離する。
class TranscriptionProgressController < ApplicationController
  def index
    materials = Material.includes(:transcriptions, file_attachment: :blob)
    @groups = materials.group_by(&:transcription_status)
  end
end
