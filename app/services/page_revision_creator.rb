module PageRevisionCreator
  module_function

  def call(page:, body:, author:, tag_names: [], edit_summary: nil)
    ApplicationRecord.transaction do
      revision = page.revisions.create!(body: body, author: author, edit_summary: edit_summary)
      page.update!(current_revision: revision)
      sync_links(page, body)
      sync_tags(page, tag_names)
      backfill_inbound_links(page)
      revision
    end
  end

  def sync_links(page, body)
    titles = WikiLinkExtractor.call(body)
    page.outgoing_links.destroy_all
    titles.each do |title|
      target = Page.find_by(title: title)
      page.outgoing_links.create!(target_title: title, target_page_id: target&.id)
    end
  end

  def sync_tags(page, tag_names)
    names = Array(tag_names).map { |n| n.to_s.strip }.reject(&:empty?).uniq
    page.tags = names.map { |name| Tag.find_or_create_by!(name: name) }
  end

  # 自分のタイトルを指す未解決リンクを埋め戻す（冪等）
  def backfill_inbound_links(page)
    Link.where(target_title: page.title, target_page_id: nil)
        .where.not(source_page_id: page.id)
        .update_all(target_page_id: page.id)
  end
end
