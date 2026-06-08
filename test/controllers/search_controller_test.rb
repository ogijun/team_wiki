require "test_helper"

class SearchControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(email_address: "s@example.com", password: "password123", name: "S")
    post session_url, params: { email_address: @user.email_address, password: "password123" }
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
end
