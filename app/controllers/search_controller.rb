class SearchController < ApplicationController
  def index
    @q = params[:q].to_s.strip
    if @q.empty?
      @articles = Article.none
      @materials = Material.none
      return
    end

    like = "%#{ActiveRecord::Base.sanitize_sql_like(@q)}%"
    @articles = Article.joins(:current_revision).includes(:current_revision)
                       .where("articles.title LIKE :q OR revisions.body LIKE :q", q: like)
                       .distinct
                       .order(updated_at: :desc)
    @materials = Material.left_joins(:transcription).includes(:transcription)
                         .where("materials.title LIKE :q OR transcriptions.body LIKE :q", q: like)
                         .distinct
                         .order(updated_at: :desc)
  end
end
