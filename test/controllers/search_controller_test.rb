require "test_helper"

class SearchControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(email_address: "s@example.com", name: "S", provider: "discord", uid: "srch-user")
    sign_in_as(@user)
    @hit = Article.create!(title: "Ruby入門", created_by: @user)
    ArticleRevisionCreator.call(article: @hit, body: "本文にキーワード含む", author: @user)
    @miss = Article.create!(title: "別物", created_by: @user)
    ArticleRevisionCreator.call(article: @miss, body: "無関係", author: @user)
  end

  test "matches title" do
    get search_url, params: { q: "Ruby" }
    assert_select "a", text: "Ruby入門"
  end

  test "matches body" do
    get search_url, params: { q: "キーワード" }
    assert_select "a", text: "Ruby入門"
  end

  test "matches transcription bodies and material titles in a 資料 section" do
    media = Material.new(user: @user, title: "検索音声")
    media.file.attach(io: StringIO.new("x"), filename: "q.mp3", content_type: "audio/mpeg")
    media.save!
    Transcription.create!(material: media, author: @user, body: "文字起こしに固有語イデオン含む", status: "drafting")
    Material.create!(user: @user, url: "https://example.com/t", title: "タイトル一致イデオン資料")

    get search_url, params: { q: "イデオン" }
    assert_select "h2", text: "資料"
    assert_select "a", text: "検索音声"
    assert_select "a", text: "タイトル一致イデオン資料"
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
