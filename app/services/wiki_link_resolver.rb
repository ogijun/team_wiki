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
end
