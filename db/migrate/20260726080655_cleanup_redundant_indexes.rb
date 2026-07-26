class CleanupRedundantIndexes < ActiveRecord::Migration[8.1]
  def change
    # 複合インデックスの先頭カラムと重複しており、単独では存在価値がない。
    remove_index :citations, column: :article_id, name: "index_citations_on_article_id"
    remove_index :likes, column: :reactor_id, name: "index_likes_on_reactor_id"
    remove_index :links, column: :source_article_id, name: "index_links_on_source_article_id"
    remove_index :taggings, column: :tag_id, name: "index_taggings_on_tag_id"
    remove_index :notifications, column: :recipient_id, name: "index_notifications_on_recipient_id"

    # 記事表示のたびに引かれる列だがインデックスが無かった。
    add_index :articles, :current_revision_id
  end
end
