class CommentsController < ApplicationController
  before_action :set_commentable, only: :create

  def create
    @comment = @commentable.comments.build(body: params.dig(:comment, :body), author: Current.user)
    if @comment.save
      ActivityRecorder.record(actor: Current.user, action: "comment.posted", subject: @commentable)
      redirect_to @commentable, notice: "コメントを投稿しました。"
    else
      redirect_to @commentable, alert: "コメントを入力してください。"
    end
  end

  def destroy
    @comment = Comment.find(params[:id])
    if @comment.deletable_by?(Current.user)
      @comment.destroy
      redirect_to @comment.commentable, notice: "コメントを削除しました。"
    else
      redirect_to @comment.commentable, alert: "このコメントを削除する権限がありません。"
    end
  end

  private

  # 記事はスラッグ、資料は id でネストされる。
  def set_commentable
    @commentable =
      if params[:article_id]
        Article.find_by!(slug: params[:article_id])
      elsif params[:material_id]
        Material.find(params[:material_id])
      else
        raise ActionController::RoutingError, "commentable not specified"
      end
  end
end
