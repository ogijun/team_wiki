class ArticlesController < ApplicationController
  before_action :set_article, only: %i[show edit update destroy]

  def index
    @articles = Article.order(updated_at: :desc)
    @articles = @articles.where(kind: params[:kind]) if Article::KINDS.key?(params[:kind])
    @articles = @articles.where(status: params[:status]) if Article::STATUSES.key?(params[:status])
  end

  def show
    body = @article.current_revision&.body.to_s
    @rendered = MarkdownRenderer.for_wiki(body).render(body)
    @backlinks = @article.inbound_links.includes(:source_article)
  end

  def new
    @article = Article.new(title: params[:title])
  end

  def create
    attributes = article_attributes
    if article_params[:body].blank?
      @article = Article.new(attributes.merge(created_by: Current.user))
      @article.errors.add(:body, "を入力してください")
      return render(:new, status: :unprocessable_entity)
    end
    @article = Article.create_with_revision!(
      attributes.merge(created_by: Current.user),
      body: article_params[:body], author: Current.user, edit_summary: article_params[:edit_summary]
    )
    Activity.record(actor: Current.user, action: "article.created", subject: @article)
    add_first_comment(@article, params[:first_comment])
    redirect_to @article, notice: "記事を作成しました。"
  rescue ActiveRecord::RecordInvalid => error
    @article = error.record if error.record.is_a?(Article)
    render :new, status: :unprocessable_entity
  end

  def edit
    @body = @article.current_revision&.body
    @tag_names = @article.tags.pluck(:name).join(", ")
  end

  def update
    # 楽観ロック: 編集画面を開いた時点の版をフォームから受け取り、save 時に比較する。
    @article.lock_version = article_params[:lock_version] if article_params[:lock_version].present?
    @article.assign_attributes(article_attributes(current_status: @article.status))
    if article_params[:body].blank?
      @article.errors.add(:body, "を入力してください")
      return rerender_edit
    end
    @article.revise!(body: article_params[:body], author: Current.user, edit_summary: article_params[:edit_summary])
    Activity.record(actor: Current.user, action: "article.edited", subject: @article)
    redirect_to @article, notice: "記事を保存しました。"
  rescue ActiveRecord::RecordInvalid
    rerender_edit
  rescue ActiveRecord::StaleObjectError
    # 他の人が先に保存済み。後勝ちの上書きはさせず、入力を保持したまま知らせる。
    @article = Article.find_by!(slug: params[:id]) # 破棄された変更で汚れた実体を読み直す
    @article.errors.add(:base, "他の編集者が先に保存しました。最新の内容を確認して、もう一度編集してください。")
    rerender_edit(status: :conflict)
  end

  def destroy
    label = @article.title
    @article.destroy
    Activity.record(actor: Current.user, action: "article.deleted", subject_label: label)
    redirect_to articles_url, notice: "記事を削除しました。"
  end

  private

  # Article 実体の属性のみ（body/edit_summary は revise! へ渡す Revision 側）。
  def article_attributes(current_status: nil)
    {
      title: article_params[:title],
      tag_names: article_params[:tag_names],
      kind: article_params[:kind].presence,
      status: article_params[:status].presence || current_status || "stub",
      start_year: article_params[:start_year], start_month: article_params[:start_month],
      start_day: article_params[:start_day], start_hour: article_params[:start_hour],
      start_minute: article_params[:start_minute],
      end_year: article_params[:end_year], end_month: article_params[:end_month],
      end_day: article_params[:end_day], end_hour: article_params[:end_hour],
      end_minute: article_params[:end_minute]
    }
  end

  def rerender_edit(status: :unprocessable_entity)
    @body = article_params[:body]
    @tag_names = article_params[:tag_names]
    render :edit, status: status
  end

  def set_article
    @article = Article.find_by!(slug: params[:id])
  end

  def article_params
    params.require(:article).permit(:title, :body, :tag_names, :edit_summary, :kind, :status,
                                    :lock_version,
                                    :start_year, :start_month, :start_day, :start_hour, :start_minute,
                                    :end_year, :end_month, :end_day, :end_hour, :end_minute)
  end
end
