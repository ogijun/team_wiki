class HomeController < ApplicationController
  def index
    @recent_articles = Article.order(updated_at: :desc).limit(5)
    @recent_activities = Activity.includes(:user, :subject).order(created_at: :desc).limit(10)
    @stub_articles = Article.where(status: %w[stub writing]).order(updated_at: :desc).limit(5)
    @stats = {
      articles: Article.count,
      materials: Material.count,
      unconfirmed_materials: Material.where(confidence: "unconfirmed").count,
      # SQLite の LENGTH(text) は文字数（バイト数ではない）を返す
      transcribed_chars: Transcription.sum("LENGTH(body)").to_i
    }
  end
end
