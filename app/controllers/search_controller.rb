class SearchController < ApplicationController
  include Pagy::Backend

  PER_PAGE = 25

  def index
    @q = params[:q].to_s.strip
    @query = SearchQuery.parse(@q)
    hits = @query.blank? ? [] : SearchRunner.call(@query)
    @pagy = Pagy.new(count: hits.size, page: params[:page], limit: PER_PAGE)
    @hits = hits[@pagy.offset, @pagy.limit] || []
  end
end
