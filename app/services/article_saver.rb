# 記事の作成/更新を1トランザクションで行うコマンド。
# 属性代入 → body必須チェック → save! + リビジョン作成 → アクティビティ記録 を集約し、
# create/update のオーケストレーションをコントローラから引き取る。
# 成功で true、失敗（body空 or RecordInvalid）で false を返し、エラーは article に乗る。
module ArticleSaver
  module_function

  def call(article:, params:, author:, action:)
    # Article 実体の属性のみ代入（body/edit_summary は Revision 側＝RevisionCreator へ渡す）。
    article.assign_attributes(
      title: params[:title],
      tag_names: params[:tag_names],
      kind: params[:kind].presence,
      status: params[:status].presence || article.status || "stub",
      start_year: params[:start_year],
      start_month: params[:start_month],
      start_day: params[:start_day],
      start_hour: params[:start_hour],
      start_minute: params[:start_minute],
      end_year: params[:end_year],
      end_month: params[:end_month],
      end_day: params[:end_day],
      end_hour: params[:end_hour],
      end_minute: params[:end_minute]
    )

    if params[:body].blank?
      article.errors.add(:body, "を入力してください")
      return false
    end

    Article.transaction do
      article.save!
      ArticleRevisionCreator.call(article: article, body: params[:body], author: author,
                                  edit_summary: params[:edit_summary])
    end
    ActivityRecorder.record(actor: author, action: "article.#{action}", subject: article)
    true
  rescue ActiveRecord::RecordInvalid
    false
  end
end
