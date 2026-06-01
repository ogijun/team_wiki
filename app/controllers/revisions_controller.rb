class RevisionsController < ApplicationController
  before_action :set_page

  def index
    @revisions = @page.revisions.order(created_at: :desc)
  end

  def show
    @revision = @page.revisions.find(params[:id])
    @base = params[:a].present? ? @page.revisions.find(params[:a]) : nil
    if @base
      @diff = Diffy::Diff.new(@base.body, @revision.body).to_s(:html).html_safe
    end
  end

  def restore
    old = @page.revisions.find(params[:id])
    PageRevisionCreator.call(page: @page, body: old.body, author: Current.user,
                             edit_summary: "リビジョン##{old.id} を復元",
                             tag_names: @page.tags.pluck(:name))
    redirect_to @page
  end

  private

  def set_page
    @page = Page.find_by!(slug: params[:page_id])
  end
end
