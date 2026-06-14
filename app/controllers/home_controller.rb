class HomeController < ApplicationController
  def index
    @recent_articles = Article.order(updated_at: :desc).limit(5)
    @recent_activities = Activity.includes(:user, :subject).order(created_at: :desc).limit(10)
    @stub_articles = Article.where(status: %w[stub writing]).order(updated_at: :desc).limit(5)
    @stats = StatSnapshot.current_values
    @my_stats = Current.user.activity_stats
    @daily = ActivityStats.daily_by_type
    @hourly = ActivityStats.hourly_by_type
  end
end
