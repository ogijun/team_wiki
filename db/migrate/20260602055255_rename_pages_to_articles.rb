class RenamePagesToArticles < ActiveRecord::Migration[8.1]
  def up
    rename_table :pages, :articles
    rename_column :revisions, :page_id, :article_id
    rename_column :materials, :page_id, :article_id
    rename_column :links, :source_page_id, :source_article_id
    rename_column :links, :target_page_id, :target_article_id

    execute "UPDATE taggings SET taggable_type = 'Article' WHERE taggable_type = 'Page'"
    execute "UPDATE activities SET subject_type = 'Article' WHERE subject_type = 'Page'"
    execute "UPDATE activities SET action = 'article.' || substr(action, 6) WHERE action LIKE 'page.%'"
  end

  def down
    execute "UPDATE activities SET action = 'page.' || substr(action, 9) WHERE action LIKE 'article.%'"
    execute "UPDATE activities SET subject_type = 'Page' WHERE subject_type = 'Article'"
    execute "UPDATE taggings SET taggable_type = 'Page' WHERE taggable_type = 'Article'"

    rename_column :links, :target_article_id, :target_page_id
    rename_column :links, :source_article_id, :source_page_id
    rename_column :materials, :article_id, :page_id
    rename_column :revisions, :article_id, :page_id
    rename_table :articles, :pages
  end
end
