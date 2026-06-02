class ChronicleController < ApplicationController
  def index
    @articles = Article.chronicled
  end
end
