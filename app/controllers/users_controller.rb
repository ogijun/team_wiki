class UsersController < ApplicationController
  def show
    @user = User.find(params[:id])
    @activities = Activity.where(user: @user).includes(:user, :subject).order(created_at: :desc).limit(20)
  end
end
