class TagsController < ApplicationController
  def index
    @tags = Tag.with_usage_count
    @tag = Tag.new
  end

  def create
    @tag = Tag.new(tag_params)
    if @tag.save
      Activity.record(actor: Current.user, action: "tag.created", subject: @tag)
      redirect_to tags_url, notice: "タグ「#{@tag.name}」を作成しました。"
    else
      @tags = Tag.with_usage_count
      render :index, status: :unprocessable_entity
    end
  end

  def show
    @tag = Tag.find_by!(slug: params[:id])
    # 資料主役: 資料を主に並べ、記事は副として残す。
    @materials = @tag.materials
                     .includes(:transcriptions, user: { avatar_attachment: :blob })
                     .with_attached_file
                     .order(created_at: :desc)
    @articles = @tag.articles.order(updated_at: :desc)
  end

  def destroy
    tag = Tag.find_by!(slug: params[:id])
    if tag.taggings.none?
      label = tag.name
      tag.destroy
      Activity.record(actor: Current.user, action: "tag.deleted", subject_label: label)
      redirect_to tags_url, notice: "タグ「#{label}」を削除しました。"
    else
      redirect_to tags_url, alert: "使用中のタグは削除できません。"
    end
  end

  private

  def tag_params
    params.require(:tag).permit(:name)
  end
end
