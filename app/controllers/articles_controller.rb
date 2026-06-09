class ArticlesController < ApplicationController
  before_action :set_article, only: %i[show edit update destroy]

  def index
    @articles = Article.order(updated_at: :desc)
    @articles = @articles.where(kind: params[:kind]) if Article::KINDS.key?(params[:kind])
    @articles = @articles.where(status: params[:status]) if Article::STATUSES.key?(params[:status])
  end

  def show
    body = @article.current_revision&.body.to_s
    @renderer = MarkdownRenderer.new(
      link_resolver: WikiLinkResolver.resolver_for(body),
      ref_resolver: ->(handle) { Material.find_by(slug: handle) }
    )
    @rendered = @renderer.render(body)
    @backlinks = @article.inbound_links.includes(:source_article)
  end

  def new
    @article = Article.new(title: params[:title])
  end

  def create
    @article = Article.new(created_by: Current.user)
    if ArticleSaver.call(article: @article, params: article_params, author: Current.user, action: "created")
      add_first_comment(@article, params[:first_comment])
      redirect_to @article
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @body = @article.current_revision&.body
    @tag_names = @article.tags.pluck(:name).join(", ")
  end

  def update
    if ArticleSaver.call(article: @article, params: article_params, author: Current.user, action: "edited")
      redirect_to @article
    else
      rerender_edit
    end
  end

  def destroy
    label = @article.title
    @article.destroy
    ActivityRecorder.record(actor: Current.user, action: "article.deleted", subject_label: label)
    redirect_to articles_url
  end

  private

  def rerender_edit
    @body = article_params[:body]
    @tag_names = article_params[:tag_names]
    render :edit, status: :unprocessable_entity
  end

  def set_article
    @article = Article.find_by!(slug: params[:id])
  end

  def article_params
    params.require(:article).permit(:title, :body, :tag_names, :edit_summary, :kind, :status,
                                    :start_year, :start_month, :start_day, :start_hour, :start_minute,
                                    :end_year, :end_month, :end_day, :end_hour, :end_minute)
  end
end
