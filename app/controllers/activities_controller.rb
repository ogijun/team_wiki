class ActivitiesController < ApplicationController
  def index
    # squash で連続活動が1グループに畳まれるぶん、グループ上限の約4倍を生取得してから
    # グループ数で頭打ちする（大きなバーストでも100グループを下回りにくいよう余裕を持たせる）。
    @activity_groups = ActivityGrouper.call(
      Activity.includes(:user, :subject).order(created_at: :desc).limit(400)
    ).first(100)
  end
end
