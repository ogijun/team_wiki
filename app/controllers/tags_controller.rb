class TagsController < ApplicationController
  def index
    @tags = Tag.order(:name)
    @tag = Tag.new
  end

  def create
    @tag = Tag.new(tag_params)
    if @tag.save
      redirect_to tags_url
    else
      @tags = Tag.order(:name)
      render :index, status: :unprocessable_entity
    end
  end

  def show
    @tag = Tag.find_by!(slug: params[:id])
    @pages = @tag.pages.order(updated_at: :desc)
  end

  private

  def tag_params
    params.require(:tag).permit(:name)
  end
end
