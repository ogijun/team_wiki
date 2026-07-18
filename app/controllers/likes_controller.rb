class LikesController < ApplicationController
  # トグル1本: 未Likeなら作成、Like済みなら削除。
  def create
    @reactable = find_reactable
    like = Like.find_by(reactor: Current.user, reactable: @reactable)
    if like
      like.destroy!
    else
      created = false
      begin
        Like.create!(reactor: Current.user, reactable: @reactable)
        created = true
      rescue ActiveRecord::RecordNotUnique
        # 二重クリック等の同時要求で両方が「未Like」を見た場合。既に付いているので冪等に成功扱い。
      end
      Notification.emit(recipient: Notification.owner_for(@reactable), actor: Current.user,
                        kind: "like", subject: @reactable) if created
    end
    # NOTE(A2): Like 作成時はここから所有者への通知を emit する（自分宛は抑制）。
    @reactable.reload

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_back fallback_location: root_path }
    end
  end

  private

  def find_reactable
    type = params.require(:reactable_type)
    raise ActionController::BadRequest unless Like::REACTABLE_TYPES.include?(type)

    type.constantize.find(params.require(:reactable_id))
  end
end
