class TagsController < ApplicationController
  def index
    @tags = Tag.with_pages_count
    @tag = Tag.new
  end

  def create
    @tag = Tag.new(tag_params)
    if @tag.save
      redirect_to tags_url
    else
      @tags = Tag.with_pages_count
      render :index, status: :unprocessable_entity
    end
  end

  def show
    @tag = Tag.find_by!(slug: params[:id])
    @pages = @tag.pages.order(updated_at: :desc)
  end

  def destroy
    tag = Tag.find_by!(slug: params[:id])
    tag.destroy if tag.pages.none?
    redirect_to tags_url
  end

  private

  def tag_params
    params.require(:tag).permit(:name)
  end
end
