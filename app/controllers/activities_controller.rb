class ActivitiesController < ApplicationController
  def index
    @activity_groups = ActivityGrouper.call(
      Activity.includes(:user, :subject).order(created_at: :desc).limit(150)
    ).first(100)
  end
end
