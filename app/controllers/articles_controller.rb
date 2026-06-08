class ArticlesController < ApplicationController
  before_action :set_article, only: %i[show edit update destroy]

  def index
    @articles = Article.order(updated_at: :desc)
    @recent_activities = Activity.includes(:user, :subject).order(created_at: :desc).limit(10)
  end

  def show
    @renderer = MarkdownRenderer.new(link_resolver: WikiLinkResolver.new.to_proc)
    @backlinks = @article.inbound_links.includes(:source_article)
  end

  def new
    @article = Article.new(title: params[:title])
  end

  def create
    @article = Article.new(title: article_params[:title], created_by: Current.user)
    if @article.save
      ArticleRevisionCreator.call(article: @article, body: article_params[:body], author: Current.user,
                                  tag_names: split_tags(article_params[:tag_names]),
                                  edit_summary: article_params[:edit_summary])
      ActivityRecorder.record(actor: Current.user, action: "article.created", subject: @article)
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
    ArticleRevisionCreator.call(article: @article, body: article_params[:body], author: Current.user,
                                tag_names: split_tags(article_params[:tag_names]),
                                edit_summary: article_params[:edit_summary])
    ActivityRecorder.record(actor: Current.user, action: "article.edited", subject: @article)
    redirect_to @article
  end

  def destroy
    label = @article.title
    @article.destroy
    ActivityRecorder.record(actor: Current.user, action: "article.deleted", subject_label: label)
    redirect_to articles_url
  end

  private

  def set_article
    @article = Article.find_by!(slug: params[:id])
  end

  def article_params
    params.require(:article).permit(:title, :body, :tag_names, :edit_summary)
  end

  def split_tags(str)
    str.to_s.split(/[,、]/).map(&:strip).reject(&:empty?)
  end
end
