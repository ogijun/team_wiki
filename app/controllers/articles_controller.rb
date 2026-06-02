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
    assign_fuzzy_dates(@article)
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
    assign_fuzzy_dates(@article)
    @article.save!
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
    params.require(:article).permit(:title, :body, :tag_names, :edit_summary,
                                    :start_year, :start_month, :start_day, :start_hour, :start_minute,
                                    :end_year, :end_month, :end_day, :end_hour, :end_minute)
  end

  def split_tags(str)
    str.to_s.split(/[,、]/).map(&:strip).reject(&:empty?)
  end

  def assign_fuzzy_dates(article)
    starts = FuzzyDate.from_parts(
      year: article_params[:start_year], month: article_params[:start_month],
      day: article_params[:start_day], hour: article_params[:start_hour], minute: article_params[:start_minute]
    )
    ends = FuzzyDate.from_parts(
      year: article_params[:end_year], month: article_params[:end_month],
      day: article_params[:end_day], hour: article_params[:end_hour], minute: article_params[:end_minute]
    )
    article.starts_at = starts&.at
    article.starts_precision = starts&.precision
    article.ends_at = ends&.at
    article.ends_precision = ends&.precision
  end
end
