class ApplicationController < ActionController::Base
  include Authentication
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  private

  # 新規作成フォームの「最初のコメント」を初回コメントとして残す（作成と一体なので
  # 単独のアクティビティは出さない）。空なら何もしない。記事・資料の create で共用。
  def add_first_comment(commentable)
    body = params[:first_comment]
    commentable.comments.create!(body: body, author: Current.user) if body.present?
  end
end
