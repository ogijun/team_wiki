require "test_helper"

class SearchIndexerTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(email_address: "idx@example.com", name: "Idx", provider: "discord", uid: "idx-user")
    SearchIndexer.rebuild!
  end

  def rows(kind:, record_id:)
    ActiveRecord::Base.connection.select_all(
      ActiveRecord::Base.sanitize_sql_array([ "SELECT * FROM search_entries WHERE kind = ? AND record_id = ?", kind, record_id ])
    ).to_a
  end

  test "記事は現在版の本文で1行。revise! で本文を変えると旧本文で当たらなくなる" do
    article = Article.create!(title: "Ruby入門", created_by: @user)
    article.revise!(body: "最初の本文", author: @user)
    SearchIndexer.reindex(article)
    assert_equal 1, rows(kind: "article", record_id: article.id).size
    assert_equal SearchNormalizer.call("最初の本文"), rows(kind: "article", record_id: article.id).first["body"]

    article.revise!(body: "書き直した本文", author: @user)
    SearchIndexer.reindex(article)
    result = rows(kind: "article", record_id: article.id)
    assert_equal 1, result.size
    assert_equal SearchNormalizer.call("書き直した本文"), result.first["body"]
  end

  test "現在版が無い記事は行を持たない" do
    article = Article.create!(title: "空", created_by: @user)
    SearchIndexer.reindex(article)
    assert_empty rows(kind: "article", record_id: article.id)
  end

  test "資料は書誌を body に、タグ名を tags に持つ。owner は自分" do
    material = Material.create!(user: @user, url: "https://example.com/m", title: "資料Ａ",
                                source: "サンプル誌", author: "サンプル著者", publisher: "出版社",
                                volume: "3号", description: "せつめい", tag_names: "ガンダム, 富野")
    SearchIndexer.reindex(material)
    result = rows(kind: "material", record_id: material.id).first
    assert_equal "資料a", result["title"]
    assert_includes result["body"], "サンプル誌"
    assert_includes result["body"], "セツメイ"
    assert_equal %w[ガンダム 富野], result["tags"].split.sort
    assert_equal "Material", result["owner_kind"]
    assert_equal material.id.to_s, result["owner_id"].to_s
  end

  test "資料のタグを付け替えると tags 列が変わる" do
    material = Material.create!(user: @user, url: "https://example.com/t", title: "t", tag_names: "旧タグ")
    SearchIndexer.reindex(material)
    material.update!(tag_names: "新タグ")
    SearchIndexer.reindex(material)
    assert_equal "新タグ", rows(kind: "material", record_id: material.id).first["tags"]
  end

  test "文字起こしはパートごとに1行。owner は親の資料。label が title" do
    material = Material.create!(user: @user, url: "https://example.com/p", title: "親資料")
    first = Transcription.create!(material: material, author: @user, body: "一つ目", label: "p.1-10", position: 1, status: "drafting")
    second = Transcription.create!(material: material, author: @user, body: "二つ目", position: 2, status: "drafting")
    SearchIndexer.reindex(first)
    SearchIndexer.reindex(second)
    result = rows(kind: "transcription", record_id: first.id).first
    assert_equal "p.1-10", result["title"]
    assert_equal "Material", result["owner_kind"]
    assert_equal material.id.to_s, result["owner_id"].to_s
    assert_equal "", rows(kind: "transcription", record_id: second.id).first["title"]
  end

  test "コメントは title 空、owner は commentable" do
    article = Article.create!(title: "記事", created_by: @user)
    article.revise!(body: "本文", author: @user)
    comment = Comment.create!(commentable: article, author: @user, body: "コメント本文")
    SearchIndexer.reindex(comment)
    result = rows(kind: "comment", record_id: comment.id).first
    assert_equal "", result["title"]
    assert_equal "コメント本文", result["body"]
    assert_equal "Article", result["owner_kind"]
    assert_equal article.id.to_s, result["owner_id"].to_s
  end

  test "発売物は title のみ" do
    publication = Publication.create!(title: "文庫版", kind: "book", registered_by: @user)
    SearchIndexer.reindex(publication)
    result = rows(kind: "publication", record_id: publication.id).first
    assert_equal "文庫版", result["title"]
    assert_equal "", result["body"]
  end

  test "remove で行が消える" do
    publication = Publication.create!(title: "消える", kind: "book", registered_by: @user)
    SearchIndexer.reindex(publication)
    SearchIndexer.remove(publication)
    assert_empty rows(kind: "publication", record_id: publication.id)
  end

  test "rebuild! は冪等で投入行数を返す" do
    Publication.create!(title: "A", kind: "book", registered_by: @user)
    Publication.create!(title: "B", kind: "book", registered_by: @user)
    first = SearchIndexer.rebuild!
    second = SearchIndexer.rebuild!
    assert_equal first, second
    assert_equal first, SearchIndexer.count
  end

  test "記事は revise! で自動的に索引され、削除で消える" do
    article = Article.create!(title: "自動索引", created_by: @user)
    article.revise!(body: "フックで入る", author: @user)
    assert_equal SearchNormalizer.call("フックで入る"), rows(kind: "article", record_id: article.id).first["body"]
    article.destroy!
    assert_empty rows(kind: "article", record_id: article.id)
  end

  test "資料は保存で自動的に索引され、削除で関連行も消える" do
    material = Material.create!(user: @user, url: "https://example.com/auto", title: "自動資料")
    transcription = Transcription.create!(material: material, author: @user, body: "パート", status: "drafting")
    comment = Comment.create!(commentable: material, author: @user, body: "コメ")
    assert_equal 1, rows(kind: "material", record_id: material.id).size
    assert_equal 1, rows(kind: "transcription", record_id: transcription.id).size
    assert_equal 1, rows(kind: "comment", record_id: comment.id).size
    material.destroy!
    assert_empty rows(kind: "material", record_id: material.id)
    assert_empty rows(kind: "transcription", record_id: transcription.id)
    assert_empty rows(kind: "comment", record_id: comment.id)
  end

  test "発売物は保存と削除で同期される" do
    publication = Publication.create!(title: "自動発売物", kind: "book", registered_by: @user)
    assert_equal 1, rows(kind: "publication", record_id: publication.id).size
    publication.update!(title: "改題")
    assert_equal "改題", rows(kind: "publication", record_id: publication.id).first["title"]
    publication.destroy!
    assert_empty rows(kind: "publication", record_id: publication.id)
  end
end
