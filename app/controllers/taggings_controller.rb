# タグ候補のワンクリック付与（記事/資料にネスト）。付けられるのは既存タグのみ。
class TaggingsController < ApplicationController
  def create
    taggable = find_taggable
    tag = Tag.find_by!(slug: params[:tag_slug])
    taggable.tag_names = (taggable.tags.pluck(:name) + [ tag.name ]).uniq.join(", ")
    taggable.save!
    redirect_to taggable, notice: "タグ #{tag.name} を追加しました。"
  end

  private

  # 記事はスラッグ、資料は id でネストされる（コメントと同じ流儀）。
  def find_taggable
    if params[:article_id]
      Article.find_by!(slug: params[:article_id])
    elsif params[:material_id]
      Material.find(params[:material_id])
    else
      raise ActionController::RoutingError, "taggable not specified"
    end
  end
end
