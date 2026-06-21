class RevisionsController < ApplicationController
  before_action :set_article

  def index
    @revisions = @article.revisions.includes(:author).order(created_at: :desc).to_a
    # newest-first list: each revision's predecessor is the next (older) one
    @previous_of = @revisions.each_cons(2).to_h { |newer, older| [ newer.id, older ] }
  end

  def show
    @revision = @article.revisions.find(params[:id])
    @base = params[:a].present? ? @article.revisions.find(params[:a]) : nil
    if @base
      @diff = Diffy::Diff.new(@base.body, @revision.body).to_s(:html).html_safe
    end
  end

  def restore
    old = @article.revisions.find(params[:id])
    @article.restore_revision!(old, author: Current.user)
    Activity.record(actor: Current.user, action: "article.edited", subject: @article)
    redirect_to @article, notice: "リビジョン##{old.id} を復元しました。"
  end

  private

  def set_article
    @article = Article.find_by!(slug: params[:article_id])
  end
end
