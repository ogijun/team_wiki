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
    ArticleRevisionCreator.call(article: article, body: "x2", author: @user)
    assert_equal [ "a" ], article.reload.tags.pluck(:name)
  end

  test "does not create a new revision when the body is unchanged" do
    article = create_article("NoOp")
    ArticleRevisionCreator.call(article: article, body: "本文", author: @user)
    assert_no_difference "Revision.count" do
      ArticleRevisionCreator.call(article: article, body: "本文", author: @user)
    end
    assert_difference "Revision.count", 1 do
      ArticleRevisionCreator.call(article: article, body: "本文2", author: @user)
    end
  end

  test "rebuilds citations resolving material handles" do
    material = Material.create!(user: @user, url: "https://example.com/s", title: "出典")
    article = create_article("Cit")
    ArticleRevisionCreator.call(article: article, body: "主張[[ref:#{material.slug}]] と [[ref:nope404]]", author: @user)

    cites = article.reload.citations
    resolved = cites.find { |c| c.material_handle == material.slug }
    broken = cites.find { |c| c.material_handle == "nope404" }
    assert_equal material.id, resolved.material_id
    assert_nil broken.material_id
  end

  test "material knows which articles cite it (many-to-many)" do
    material = Material.create!(user: @user, url: "https://example.com/s2", title: "出典2")
    a1 = create_article("A1")
    a2 = create_article("A2")
    ArticleRevisionCreator.call(article: a1, body: "[[ref:#{material.slug}]]", author: @user)
    ArticleRevisionCreator.call(article: a2, body: "[[ref:#{material.slug}]]", author: @user)
    assert_equal %w[A1 A2], material.reload.citing_articles.order(:title).pluck(:title)
  end

  test "removes citations no longer present on next save" do
    material = Material.create!(user: @user, url: "https://example.com/s3", title: "出典3")
    article = create_article("C2")
    ArticleRevisionCreator.call(article: article, body: "[[ref:#{material.slug}]]", author: @user)
    ArticleRevisionCreator.call(article: article, body: "参照なし", author: @user)
    assert_equal 0, article.reload.citations.count
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
