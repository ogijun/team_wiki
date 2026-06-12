module ArticlesHelper
  # 記事一覧の小さなメタ行（状態・種別 / 更新日 ・コメント件数）を組み立てる。
  def article_meta(article)
    kind = "・#{article.kind_label}" if article.kind
    base = "#{article.status_label}#{kind} / #{article.updated_at.to_date.to_fs(:jp)}"
    return base unless article.comments_count.positive?
    safe_join([ base, " ・", icon("message-circle"), article.comments_count.to_s ])
  end
end
