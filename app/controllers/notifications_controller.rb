class NotificationsController < ApplicationController
  def index
    @seen_boundary = Current.user.notifications_seen_at || Current.user.created_at
    notifications = Current.user.notifications.includes(:actor, :subject).order(created_at: :desc)
    notifications = notifications.where("created_at < ?", Time.zone.parse(params[:before])) if params[:before].present?
    @notifications = notifications.limit(50)
    @next_before = @notifications.last.created_at.iso8601(6) if @notifications.size == 50
    Current.user.update_column(:notifications_seen_at, Time.current)
  end
end
