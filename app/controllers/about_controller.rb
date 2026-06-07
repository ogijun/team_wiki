class AboutController < ApplicationController
  def show
    @setting = SiteSetting.instance
    return if @setting.about.blank?

    body = @setting.about
    links = WikiLinkResolver.resolve_all(WikiLinkExtractor.call(body))
    @rendered = MarkdownRenderer.new(
      link_resolver: ->(title) { links[title] || WikiLinkResolver.call(title) },
      ref_resolver: ->(handle) { Material.find_by(slug: handle) }
    ).render(body)
  end
end
