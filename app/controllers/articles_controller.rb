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
    @article.assign_attributes(article_attributes)
    if article_params[:body].blank?
      @article.errors.add(:body, "を入力してください")
      return render(:new, status: :unprocessable_entity)
    end
    @article.revise!(body: article_params[:body], author: Current.user, edit_summary: article_params[:edit_summary])
    Activity.record(actor: Current.user, action: "article.created", subject: @article)
    add_first_comment(@article, params[:first_comment])
    redirect_to @article
  rescue ActiveRecord::RecordInvalid
    render :new, status: :unprocessable_entity
  end

  def edit
    @body = @article.current_revision&.body
    @tag_names = @article.tags.pluck(:name).join(", ")
  end

  def update
    @article.assign_attributes(article_attributes)
    if article_params[:body].blank?
      @article.errors.add(:body, "を入力してください")
      return rerender_edit
    end
    @article.revise!(body: article_params[:body], author: Current.user, edit_summary: article_params[:edit_summary])
    Activity.record(actor: Current.user, action: "article.edited", subject: @article)
    redirect_to @article
  rescue ActiveRecord::RecordInvalid
    rerender_edit
  end

  def destroy
    label = @article.title
    @article.destroy
    Activity.record(actor: Current.user, action: "article.deleted", subject_label: label)
    redirect_to articles_url
  end

  private

  # Article 実体の属性のみ（body/edit_summary は revise! へ渡す Revision 側）。
  def article_attributes
    {
      title: article_params[:title],
      tag_names: article_params[:tag_names],
      kind: article_params[:kind].presence,
      status: article_params[:status].presence || @article.status || "stub",
      start_year: article_params[:start_year], start_month: article_params[:start_month],
      start_day: article_params[:start_day], start_hour: article_params[:start_hour],
      start_minute: article_params[:start_minute],
      end_year: article_params[:end_year], end_month: article_params[:end_month],
      end_day: article_params[:end_day], end_hour: article_params[:end_hour],
      end_minute: article_params[:end_minute]
    }
  end

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
