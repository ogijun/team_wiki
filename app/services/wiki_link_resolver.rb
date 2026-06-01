class WikiLinkResolver
  include Rails.application.routes.url_helpers

  def call(title)
    page = Page.find_by(title: title)
    if page
      { href: page_path(page), exists: true }
    else
      { href: new_page_path(title: title), exists: false }
    end
  end

  def to_proc
    method(:call).to_proc
  end
end
