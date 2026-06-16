require "test_helper"

class ArticleRevisingTest < ActiveSupport::TestCase
  setup { @user = User.create!(email_address: "ar@example.com", password: "password123", name: "AR") }

  def create_article(title)
    Article.create!(title: title, created_by: @user)
  end

  test "revise! creates a revision and sets current_revision, returns it" do
    article = create_article("Doc")
    rev = article.revise!(body: "本文", author: @user)
    assert_equal rev, article.reload.current_revision
    assert_equal "本文", article.current_revision.body
  end

  test "revise! persists the article's own attribute changes too" do
    article = create_article("Old")
    article.title = "New"
    article.revise!(body: "x", author: @user)
    assert_equal "New", article.reload.title
  end

  test "revise! bumps updated_at when the body changes" do
    article = create_article("Bump")
    article.revise!(body: "v1", author: @user)
    original = article.reload.updated_at
    travel 1.second do
      article.revise!(body: "v2", author: @user)
    end
    assert_operator article.reload.updated_at, :>, original
  end

  test "revise! does not create a new revision when body is unchanged" do
    article = create_article("NoOp")
    article.revise!(body: "本文", author: @user)
    assert_no_difference "Revision.count" do
      article.revise!(body: "本文", author: @user)
    end
    assert_difference "Revision.count", 1 do
      article.revise!(body: "本文2", author: @user)
    end
  end

  test "revise! rebuilds outgoing links resolving existing targets" do
    target = create_article("ターゲット")
    target.revise!(body: "x", author: @user)
    article = create_article("Src")
    article.revise!(body: "[[ターゲット]] と [[未作成]]", author: @user)
    links = article.reload.outgoing_links.order(:target_title)
    assert_equal target.id, links.find { |l| l.target_title == "ターゲット" }.target_article_id
    assert_nil links.find { |l| l.target_title == "未作成" }.target_article_id
  end

  test "revise! rebuilds citations resolving material handles" do
    material = Material.create!(user: @user, url: "https://example.com/s", title: "出典")
    article = create_article("Cit")
    article.revise!(body: "主張[[ref:#{material.slug}]] と [[ref:nope404]]", author: @user)
    cites = article.reload.citations
    assert_equal material.id, cites.find { |c| c.material_handle == material.slug }.material_id
    assert_nil cites.find { |c| c.material_handle == "nope404" }.material_id
  end

  test "revise! removes citations no longer present on next revise" do
    material = Material.create!(user: @user, url: "https://example.com/s3", title: "出典3")
    article = create_article("C2")
    article.revise!(body: "[[ref:#{material.slug}]]", author: @user)
    article.revise!(body: "参照なし", author: @user)
    assert_equal 0, article.reload.citations.count
  end

  test "revise! backfills inbound broken links when the target article is revised into existence" do
    src = create_article("Linker")
    src.revise!(body: "[[あとで作る]]", author: @user)
    assert_nil src.outgoing_links.first.target_article_id
    later = create_article("あとで作る")
    later.revise!(body: "本文", author: @user)
    assert_equal later.id, src.outgoing_links.first.reload.target_article_id
  end

  test "revise! does not record an activity (controller's responsibility)" do
    article = create_article("NoActivity")
    assert_no_difference "Activity.count" do
      article.revise!(body: "本文", author: @user)
    end
  end

  test "create_with_revision! creates the article and its first revision without activity" do
    article = nil
    assert_no_difference "Activity.count" do
      article = Article.create_with_revision!(
        { title: "新規", status: "stub", created_by: @user }, body: "初版本文", author: @user
      )
    end
    assert_predicate article, :persisted?
    assert_equal "初版本文", article.current_revision.body
  end

  test "restore_revision! revises to an old body, carries current tags, no activity" do
    article = create_article("Restorable")
    article.tag_names = "a, b"
    article.revise!(body: "v1", author: @user)
    old = article.current_revision
    article.revise!(body: "v2", author: @user)
    assert_no_difference "Activity.count" do
      article.restore_revision!(old, author: @user)
    end
    assert_equal "v1", article.reload.current_revision.body
    assert_equal %w[a b], article.tags.pluck(:name).sort
  end
end
