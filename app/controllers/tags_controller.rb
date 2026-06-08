class TagsController < ApplicationController
  def index
    @tags = Tag.with_usage_count
    @tag = Tag.new
  end

  def create
    @tag = Tag.new(tag_params)
    if @tag.save
      ActivityRecorder.record(actor: Current.user, action: "tag.created", subject: @tag)
      redirect_to tags_url
    else
      @tags = Tag.with_usage_count
      render :index, status: :unprocessable_entity
    end
  end

  def show
    @tag = Tag.find_by!(slug: params[:id])
    @articles = @tag.articles.order(updated_at: :desc)
  end

  def destroy
    tag = Tag.find_by!(slug: params[:id])
    if tag.taggings.none?
      label = tag.name
      tag.destroy
      ActivityRecorder.record(actor: Current.user, action: "tag.deleted", subject_label: label)
    end
    redirect_to tags_url
  end

  private

  def tag_params
    params.require(:tag).permit(:name)
  end
end
