require "test_helper"

class SearchRunnerTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(email_address: "run@example.com", name: "Run", provider: "discord", uid: "run-user")
    @title_hit = Article.create!(title: "ガンダム大全", created_by: @user)
    @title_hit.revise!(body: "本文はさておき", author: @user)
    @body_hit = Article.create!(title: "雑記", created_by: @user)
    @body_hit.revise!(body: "本文の中にガンダムが出てくる", author: @user)
    @material = Material.create!(user: @user, url: "https://example.com/r", title: "資料", tag_names: "ガンダム")
    @t1 = Transcription.create!(material: @material, author: @user, body: "文字起こしにガンダム", position: 1, status: "drafting")
    @t2 = Transcription.create!(material: @material, author: @user, body: "こちらにもガンダム", position: 2, status: "drafting")
  end

  def search(raw) = SearchRunner.call(SearchQuery.parse(raw))

  test "種別横断で1リストになり、タイトル一致が本文一致より上に来る" do
    owners = search("ガンダム").map(&:owner)
    assert_includes owners, @title_hit
    assert_includes owners, @body_hit
    assert_includes owners, @material
    assert_operator owners.index(@title_hit), :<, owners.index(@body_hit)
  end

  test "同じ owner に複数行が当たっても1件に畳まれ、via が代表ヒットを指す" do
    hits = search("ガンダム")
    material_hits = hits.select { |h| h.owner == @material }
    assert_equal 1, material_hits.size
    assert_includes [ @material, @t1, @t2 ], material_hits.first.via
  end

  test "除外語が効く" do
    owners = search("ガンダム -さておき").map(&:owner)
    assert_not_includes owners, @title_hit
    assert_includes owners, @body_hit
  end

  test "フレーズは語順違いに当たらない" do
    assert_includes search('"本文の中に"').map(&:owner), @body_hit
    assert_empty search('"中に本文の"')
  end

  test "2文字語だけの検索が当たる（LIKE 補完）" do
    a = Article.create!(title: "富野の本", created_by: @user)
    a.revise!(body: "x", author: @user)
    assert_includes search("富野").map(&:owner), a
  end

  test "2文字語と3文字語の混在: 両方を満たすものだけ" do
    a = Article.create!(title: "富野とガンダム", created_by: @user)
    a.revise!(body: "x", author: @user)
    owners = search("富野 ガンダム").map(&:owner)
    assert_includes owners, a
    assert_not_includes owners, @title_hit
  end

  test "短い除外語が効く" do
    a = Article.create!(title: "富野とガンダム", created_by: @user)
    a.revise!(body: "x", author: @user)
    assert_not_includes search("ガンダム -富野").map(&:owner), a
    assert_includes search("ガンダム -富野").map(&:owner), @title_hit
  end

  test "短い通常語だけの検索でも3文字以上の除外語が効く" do
    excluded = Article.create!(title: "富野とガンダム", created_by: @user)
    excluded.revise!(body: "x", author: @user)
    included = Article.create!(title: "富野の本", created_by: @user)
    included.revise!(body: "y", author: @user)

    owners = search("富野 -ガンダム").map(&:owner)
    assert_not_includes owners, excluded
    assert_includes owners, included
  end

  test "表記ゆれ: ひらがな・全角で書いても当たる" do
    assert_includes search("がんだむ").map(&:owner), @title_hit
    en = Article.create!(title: "gundam", created_by: @user)
    en.revise!(body: "y", author: @user)
    assert_includes search("ＧＵＮＤＡＭ").map(&:owner), en
  end

  test "空クエリは空配列" do
    assert_equal [], search("")
  end

  test "索引が空でも例外にならず 0 件" do
    ActiveRecord::Base.connection.execute("DELETE FROM search_entries")
    assert_equal [], search("ガンダム")
  end
end
