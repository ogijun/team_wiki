class TagsController < ApplicationController
  def index
    @tags = Tag.order(:name)
  end

  def show
    @tag = Tag.find_by!(slug: params[:id])
    @pages = @tag.pages.order(updated_at: :desc)
  end
end
