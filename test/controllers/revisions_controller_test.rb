require "test_helper"

class RevisionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(email_address: "rv@example.com", password: "password123", name: "RV")
    post session_url, params: { email_address: @user.email_address, password: "password123" }
    @page = Page.create!(title: "Hist", created_by: @user)
    @r1 = PageRevisionCreator.call(page: @page, body: "一行目", author: @user)
    @r2 = PageRevisionCreator.call(page: @page, body: "一行目\n二行目", author: @user)
  end

  test "index lists revisions newest first" do
    get page_revisions_url(@page)
    assert_response :success
    assert_select "li", minimum: 2
  end

  test "show with a and b shows a diff" do
    get page_revision_url(@page, @r2), params: { a: @r1.id }
    assert_response :success
    assert_select ".diff"
  end

  test "restore creates a new revision from an old body" do
    assert_difference("@page.revisions.count", 1) do
      post restore_page_revision_url(@page, @r1)
    end
    assert_equal "一行目", @page.reload.current_revision.body
  end
end
