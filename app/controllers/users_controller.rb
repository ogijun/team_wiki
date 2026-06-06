class UsersController < ApplicationController
  before_action :require_admin, only: :index

  def index
    @users = User.with_attached_avatar.order(:created_at)
    @last_activity = Activity.group(:user_id).maximum(:created_at)
  end

  def show
    @user = User.find(params[:id])
    @activities = Activity.where(user: @user).includes(:user, :subject).order(created_at: :desc).limit(20)
  end
end
