class HomeController < ApplicationController
  def index
    @recent_articles = Article.order(updated_at: :desc).limit(5)
    @recent_activities = Activity.includes(:user, :subject).order(created_at: :desc).limit(10)
    @stub_articles = Article.where(status: %w[stub writing]).order(updated_at: :desc).limit(5)
    @stats = {
      articles: Article.count,
      materials: Material.count,
      unconfirmed_materials: Material.where(confidence: "unconfirmed").count
    }
  end
end
