module ArticleRevisionCreator
  module_function

  def call(article:, body:, author:, tag_names: [], edit_summary: nil)
    ApplicationRecord.transaction do
      revision = article.revisions.create!(body: body, author: author, edit_summary: edit_summary)
      article.update!(current_revision: revision)
      sync_links(article, body)
      sync_tags(article, tag_names)
      backfill_inbound_links(article)
      revision
    end
  end

  def sync_links(article, body)
    titles = WikiLinkExtractor.call(body)
    article.outgoing_links.destroy_all
    by_title = Article.where(title: titles).index_by(&:title)
    titles.each do |title|
      article.outgoing_links.create!(target_title: title, target_article_id: by_title[title]&.id)
    end
  end

  def sync_tags(article, tag_names)
    names = Array(tag_names).map { |n| n.to_s.strip }.reject(&:empty?).uniq
    article.tags = names.map { |name| Tag.find_or_create_by!(name: name) }
  end

  # 自分のタイトルを指す未解決リンクを埋め戻す（冪等）
  def backfill_inbound_links(article)
    Link.where(target_title: article.title, target_article_id: nil)
        .where.not(source_article_id: article.id)
        .update_all(target_article_id: article.id)
  end
end
