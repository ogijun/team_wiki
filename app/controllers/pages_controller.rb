class PagesController < ApplicationController
  before_action :set_page, only: %i[show edit update destroy]

  def index
    @pages = Page.order(updated_at: :desc)
  end

  def show
    @renderer = MarkdownRenderer.new(link_resolver: WikiLinkResolver.new.to_proc)
    @backlinks = @page.inbound_links.includes(:source_page)
  end

  def new
    @page = Page.new(title: params[:title])
  end

  def create
    @page = Page.new(title: page_params[:title], created_by: Current.user)
    if @page.save
      PageRevisionCreator.call(page: @page, body: page_params[:body], author: Current.user,
                               tag_names: split_tags(page_params[:tag_names]),
                               edit_summary: page_params[:edit_summary])
      redirect_to @page
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @body = @page.current_revision&.body
    @tag_names = @page.tags.pluck(:name).join(", ")
  end

  def update
    PageRevisionCreator.call(page: @page, body: page_params[:body], author: Current.user,
                             tag_names: split_tags(page_params[:tag_names]),
                             edit_summary: page_params[:edit_summary])
    redirect_to @page
  end

  def destroy
    @page.destroy
    redirect_to pages_url
  end

  private

  def set_page
    @page = Page.find_by!(slug: params[:id])
  end

  def page_params
    params.require(:page).permit(:title, :body, :tag_names, :edit_summary)
  end

  def split_tags(str)
    str.to_s.split(/[,、]/).map(&:strip).reject(&:empty?)
  end
end
