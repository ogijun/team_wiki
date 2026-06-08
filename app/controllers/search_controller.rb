class SearchController < ApplicationController
  def index
    @q = params[:q].to_s.strip
    @articles =
      if @q.empty?
        Article.none
      else
        like = "%#{ActiveRecord::Base.sanitize_sql_like(@q)}%"
        Article.joins(:current_revision)
               .where("articles.title LIKE :q OR revisions.body LIKE :q", q: like)
               .distinct
               .order(updated_at: :desc)
      end
  end
end
