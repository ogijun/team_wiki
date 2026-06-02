class ActivitiesController < ApplicationController
  def index
    @activities = Activity.includes(:user, :subject).order(created_at: :desc).limit(100)
  end
end
