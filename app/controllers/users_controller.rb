class UsersController < ApplicationController
  before_action :require_admin, only: :index

  def index
    @users = User.with_attached_avatar.order(:created_at)
    @last_activity = Activity.group(:user_id).maximum(:created_at)
    # 最終ログイン＝最新セッションの作成時刻（@last_activity と同じ group-maximum パターン）。
    # ログアウトでセッションは消えるので、有効セッションが無いユーザは空欄になる。
    @last_login = Session.group(:user_id).maximum(:created_at)
  end

  def show
    @user = User.find(params[:id])
    # グループ上限の約4倍を生取得してから頭打ち（squash 後もグループ数を確保するための余裕）。
    @activity_groups = ActivityGrouper.call(
      Activity.where(user: @user).includes(:user, :subject).order(created_at: :desc).limit(60)
    ).first(15)
    @favorites = Like.where(reactor: @user).includes(:reactable).order(created_at: :desc).limit(20) if @user == Current.user
  end
end
