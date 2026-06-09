# 資料アップロード時に、その資料を引用するスタブ記事を1つ自動生成する。
# 本文は案内一文＋[[ref:資料slug]] のみ。保存時に ArticleRevisionCreator が
# citations を張るので、Material↔Article の多対多が永続化される。
module StubArticleForMaterial
  module_function

  GUIDANCE = "この資料をもとにしたスタブ記事です。下の出典をもとに加筆してください。".freeze

  def call(material:, author:)
    article = Article.new(title: unique_title(material.title), status: "stub", created_by: author)
    body = "#{GUIDANCE}\n\n[[ref:#{material.slug}]]\n"
    Article.transaction do
      article.save!
      ArticleRevisionCreator.call(article: article, body: body, author: author, edit_summary: "資料から自動作成")
    end
    ActivityRecorder.record(actor: author, action: "article.created", subject: article)
    article
  end

  # Article タイトルは一意。同名があれば「（2）」「（3）」…を付けて別記事にする。
  def unique_title(base)
    base = base.to_s.strip.presence || "無題の資料"
    return base unless Article.exists?(title: base)
    n = 2
    n += 1 while Article.exists?(title: "#{base}（#{n}）")
    "#{base}（#{n}）"
  end
end
