# 記事タイトルを { href:, exists: } に解決するステートレスな resolver。
# MarkdownRenderer に callable(WikiLinkResolver.method(:call)) として注入される。
module WikiLinkResolver
  module_function

  def call(title)
    routes = Rails.application.routes.url_helpers
    article = Article.find_by(title: title)
    if article
      { href: routes.article_path(article), exists: true }
    else
      { href: routes.new_article_path(title: title), exists: false }
    end
  end

  # 複数タイトルを1クエリで解決し、title => { href:, exists: } の Hash を返す。
  # MarkdownRenderer の link_resolver に「本文から抽出した全タイトル」分を前もって渡し、
  # [[リンク]] ごとの find_by（N+1）を避ける。
  def resolve_all(titles)
    titles = titles.uniq
    found = Article.where(title: titles).index_by(&:title)
    routes = Rails.application.routes.url_helpers
    titles.index_with do |title|
      article = found[title]
      if article
        { href: routes.article_path(article), exists: true }
      else
        { href: routes.new_article_path(title: title), exists: false }
      end
    end
  end
end
