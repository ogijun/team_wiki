require "test_helper"

class ArticleRevisionCreatorTest < ActiveSupport::TestCase
  setup { @user = User.create!(email_address: "c@example.com", password: "password123", name: "C") }

  def create_article(title)
    Article.create!(title: title, created_by: @user)
  end

  test "creates revision and sets current_revision" do
    article = create_article("Doc")
    rev = ArticleRevisionCreator.call(article: article, body: "本文", author: @user)
    assert_equal rev, article.reload.current_revision
    assert_equal "本文", article.current_revision.body
  end

  test "rebuilds outgoing links resolving existing targets" do
    target = create_article("ターゲット")
    ArticleRevisionCreator.call(article: target, body: "x", author: @user)
    article = create_article("Src")
    ArticleRevisionCreator.call(article: article, body: "[[ターゲット]] と [[未作成]]", author: @user)

    links = article.reload.outgoing_links.order(:target_title)
    resolved = links.find { |l| l.target_title == "ターゲット" }
    broken = links.find { |l| l.target_title == "未作成" }
    assert_equal target.id, resolved.target_article_id
    assert_nil broken.target_article_id
  end

  test "syncs tags from names (via Taggable on save)" do
    article = create_article("Tagged")
    article.tag_names = "ruby, rails"
    ArticleRevisionCreator.call(article: article, body: "x", author: @user)
    assert_equal %w[rails ruby], article.reload.tags.pluck(:name).sort
  end

  test "removes tags no longer present on next save" do
    article = create_article("Retag")
    article.tag_names = "a, b"
    ArticleRevisionCreator.call(article: article, body: "x", author: @user)
    article.tag_names = "a"
    ArticleRevisionCreator.call(article: article, body: "x", author: @user)
    assert_equal [ "a" ], article.reload.tags.pluck(:name)
  end

  test "backfills inbound broken links when target article is created" do
    src = create_article("Linker")
    ArticleRevisionCreator.call(article: src, body: "[[あとで作る]]", author: @user)
    assert_nil src.outgoing_links.first.target_article_id

    later = create_article("あとで作る")
    ArticleRevisionCreator.call(article: later, body: "本文", author: @user)

    assert_equal later.id, src.outgoing_links.first.reload.target_article_id
  end
end
