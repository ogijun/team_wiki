class WikiLinkResolver
  include Rails.application.routes.url_helpers

  def call(title)
    article = Article.find_by(title: title)
    if article
      { href: article_path(article), exists: true }
    else
      { href: new_article_path(title: title), exists: false }
    end
  end

  def to_proc
    method(:call).to_proc
  end
end
