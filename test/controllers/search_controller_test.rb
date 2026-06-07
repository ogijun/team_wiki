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
