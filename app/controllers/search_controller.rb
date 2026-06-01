class SearchController < ApplicationController
  def index
    @q = params[:q].to_s.strip
    @pages =
      if @q.empty?
        Page.none
      else
        like = "%#{ActiveRecord::Base.sanitize_sql_like(@q)}%"
        Page.joins(:current_revision)
            .where("pages.title LIKE :q OR revisions.body LIKE :q", q: like)
            .distinct
            .order(updated_at: :desc)
      end
  end
end
