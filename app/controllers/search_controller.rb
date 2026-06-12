class SearchController < ApplicationController
  def index
    @q = params[:q].to_s.strip
    if @q.empty?
      @results = []
      return
    end

    like = "%#{ActiveRecord::Base.sanitize_sql_like(@q)}%"
    articles = Article.joins(:current_revision).includes(:current_revision)
                      .where("articles.title LIKE :q OR revisions.body LIKE :q", q: like)
                      .distinct
    materials = Material.left_joins(:transcription).includes(:transcription)
                        .where("materials.title LIKE :q OR transcriptions.body LIKE :q", q: like)
                        .distinct
    # 記事と資料を混ぜて最新順に（件数は LIKE 検索の現スケールでは小さい前提）
    @results = (articles.to_a + materials.to_a).sort_by(&:updated_at).reverse
  end
end
