class NotificationsController < ApplicationController
  def index
    @seen_boundary = Current.user.notifications_seen_at || Current.user.created_at
    notifications = Current.user.notifications.includes(:actor, :subject).order(created_at: :desc)
    notifications = notifications.where("created_at < ?", Time.zone.parse(params[:before])) if params[:before].present?
    limit = turbo_frame_request? ? 7 : 50
    records = notifications.limit(limit + 1).to_a
    @has_more = records.size > limit
    @notifications = records.first(limit)
    @next_before = @notifications.last.created_at.iso8601(6) if @has_more && !turbo_frame_request?
    Current.user.update_column(:notifications_seen_at, Time.current)

    render :popover if turbo_frame_request?
  end
end
