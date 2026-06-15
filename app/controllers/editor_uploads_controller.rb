# リッチテキストエディタにドラッグ/ペーストされた画像・動画をインライン埋め込み用に受け取り、
# 埋め込み URL を返す（資料 Material の登録とは別経路）。レコードは Upload モデル。
class EditorUploadsController < ApplicationController
  def create
    upload = Upload.new(user: Current.user)
    upload.file.attach(params[:file])
    if upload.save
      render json: { url: url_for(upload.file) }
    else
      render json: { errors: upload.errors.full_messages }, status: :unprocessable_entity
    end
  end
end
