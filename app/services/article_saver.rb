# 記事の作成/更新を1トランザクションで行うコマンド。
# 属性代入 → body必須チェック → save! + リビジョン作成 → アクティビティ記録 を集約し、
# create/update のオーケストレーションをコントローラから引き取る。
# 成功で true、失敗（body空 or RecordInvalid）で false を返し、エラーは article に乗る。
module ArticleSaver
  module_function

  # action: "created" | "edited"
  def call(article:, params:, author:, action:)
    assign_attributes(article, params)
    if params[:body].blank?
      article.errors.add(:body, "を入力してください")
      return false
    end
    Article.transaction do
      article.save!
      ArticleRevisionCreator.call(article: article, body: params[:body], author: author,
                                  tag_names: split_tags(params[:tag_names]), edit_summary: params[:edit_summary])
    end
    ActivityRecorder.record(actor: author, action: "article.#{action}", subject: article)
    true
  rescue ActiveRecord::RecordInvalid
    false
  end

  def assign_attributes(article, params)
    article.title = params[:title]
    article.kind = params[:kind].presence
    article.status = params[:status].presence || article.status || "stub"
    assign_fuzzy_dates(article, params)
  end

  def assign_fuzzy_dates(article, params)
    starts = FuzzyDate.from_parts(
      year: params[:start_year], month: params[:start_month],
      day: params[:start_day], hour: params[:start_hour], minute: params[:start_minute]
    )
    ends = FuzzyDate.from_parts(
      year: params[:end_year], month: params[:end_month],
      day: params[:end_day], hour: params[:end_hour], minute: params[:end_minute]
    )
    article.starts_at = starts&.at
    article.starts_precision = starts&.precision
    article.ends_at = ends&.at
    article.ends_precision = ends&.precision
  end

  # 区切り分割のみ。strip/reject/uniq は ArticleRevisionCreator.sync_tags が行う。
  def split_tags(str)
    str.to_s.split(/[,、]/)
  end
end
