require "test_helper"

class SearchControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(email_address: "s@example.com", name: "S", provider: "discord", uid: "srch-user")
    sign_in_as(@user)
    @hit = Article.create!(title: "Ruby入門", created_by: @user)
    @hit.revise!(body: "本文にキーワード含む", author: @user)
    @miss = Article.create!(title: "別物", created_by: @user)
    @miss.revise!(body: "無関係", author: @user)
  end

  test "matches title" do
    get search_url, params: { q: "Ruby" }
    assert_select "a", text: "Ruby入門"
  end

  test "matches body" do
    get search_url, params: { q: "キーワード" }
    assert_select "a", text: "Ruby入門"
  end

  test "matches transcription bodies and material titles" do
    media = Material.new(user: @user, title: "検索音声")
    media.file.attach(io: StringIO.new("x"), filename: "q.mp3", content_type: "audio/mpeg")
    media.save!
    Transcription.create!(material: media, author: @user, body: "文字起こしに固有語サンプル語含む", status: "drafting")
    Material.create!(user: @user, url: "https://example.com/t", title: "タイトル一致サンプル語資料")

    get search_url, params: { q: "サンプル語" }
    assert_select "a", text: "検索音声"
    assert_select ".search-results a mark", text: "サンプル語" # タイトル内マッチもハイライト
  end

  test "search matches any transcription part body" do
    m = Material.new(user: @user, title: "検索対象音声")
    m.file.attach(io: StringIO.new("x"), filename: "s.mp3", content_type: "audio/mpeg")
    m.save!
    m.transcriptions.create!(author: @user, body: "前半はりんごの話", position: 1)
    m.transcriptions.create!(author: @user, body: "後半はみかんの話", position: 2)
    get search_url(q: "みかん")
    assert_response :success
    assert_select "a", text: /検索対象音声/
  end

  test "mixes articles and materials sorted by updated_at desc" do
    @hit.update!(updated_at: 2.hours.ago)
    m = Material.create!(user: @user, url: "https://example.com/mix", title: "新しいRubyの資料")
    m.update!(updated_at: 1.hour.ago)

    get search_url, params: { q: "Ruby" }
    assert_select ".search-results", count: 1 # セクション分けせず単一リスト
    body = response.body
    # タイトル内のマッチは <mark> で分断されるので、マーク境界を跨がない部分で順序を見る
    assert_operator body.index("の資料"), :<, body.index("入門"), "新しい方が先に出る"
  end

  test "results show highlighted snippets around the match" do
    get search_url, params: { q: "キーワード" }
    assert_select ".search-snippet mark", text: "キーワード"
    assert_select ".search-snippet", text: /本文に.*含む/m

    media = Material.new(user: @user, title: "断片音声")
    media.file.attach(io: StringIO.new("x"), filename: "h.mp3", content_type: "audio/mpeg")
    media.save!
    Transcription.create!(material: media, author: @user,
                          body: "前置き" * 30 + "ハイライト対象" + "後続" * 30, status: "drafting")
    get search_url, params: { q: "ハイライト対象" }
    assert_select ".search-snippet mark", text: "ハイライト対象"
  end

  test "empty query returns no results section error" do
    get search_url, params: { q: "" }
    assert_response :success
  end

  test "shows the full-text-not-enabled note when a query is present" do
    get search_url, params: { q: "Ruby" }
    assert_select "p.search-note"
  end

  test "omits the note when no query" do
    get search_url, params: { q: "" }
    assert_select "p.search-note", count: 0
  end
end
