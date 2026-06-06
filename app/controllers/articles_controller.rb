class ArticlesController < ApplicationController
  before_action :set_article, only: %i[show edit update destroy]

  def index
    @articles = Article.order(updated_at: :desc)
    @articles = @articles.where(kind: params[:kind]) if Article::KINDS.key?(params[:kind])
    @articles = @articles.where(status: params[:status]) if Article::STATUSES.key?(params[:status])
    @recent_activities = Activity.includes(:user, :subject).order(created_at: :desc).limit(10)
  end

  def show
    @renderer = MarkdownRenderer.new(
      link_resolver: WikiLinkResolver.method(:call),
      ref_resolver: ->(handle) { Material.find_by(slug: handle) }
    )
    @rendered = @renderer.render(@article.current_revision&.body.to_s)
    @backlinks = @article.inbound_links.includes(:source_article)
  end

  def new
    @article = Article.new(title: params[:title])
  end

  def create
    @article = Article.new(title: article_params[:title], created_by: Current.user,
                           kind: article_params[:kind].presence,
                           status: article_params[:status].presence || "stub")
    assign_fuzzy_dates(@article)
    if article_params[:body].blank?
      @article.errors.add(:body, "を入力してください")
      return render :new, status: :unprocessable_entity
    end
    Article.transaction do
      @article.save!
      ArticleRevisionCreator.call(article: @article, body: article_params[:body], author: Current.user,
                                  tag_names: split_tags(article_params[:tag_names]),
                                  edit_summary: article_params[:edit_summary])
    end
    ActivityRecorder.record(actor: Current.user, action: "article.created", subject: @article)
    redirect_to @article
  rescue ActiveRecord::RecordInvalid
    render :new, status: :unprocessable_entity
  end

  def edit
    @body = @article.current_revision&.body
    @tag_names = @article.tags.pluck(:name).join(", ")
  end

  def update
    @article.title = article_params[:title]
    @article.kind = article_params[:kind].presence
    @article.status = article_params[:status].presence || @article.status
    assign_fuzzy_dates(@article)
    if article_params[:body].blank?
      @article.errors.add(:body, "を入力してください")
      return rerender_edit
    end
    Article.transaction do
      @article.save!
      ArticleRevisionCreator.call(article: @article, body: article_params[:body], author: Current.user,
                                  tag_names: split_tags(article_params[:tag_names]),
                                  edit_summary: article_params[:edit_summary])
    end
    ActivityRecorder.record(actor: Current.user, action: "article.edited", subject: @article)
    redirect_to @article
  rescue ActiveRecord::RecordInvalid
    rerender_edit
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
