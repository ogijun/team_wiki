require "test_helper"

class PagesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(email_address: "p@example.com", password: "password123", name: "P")
  end

  def login
    post session_url, params: { email_address: @user.email_address, password: "password123" }
  end

  test "index requires login" do
    get pages_url
    assert_redirected_to new_session_url
  end

  test "create makes page with first revision" do
    login
    assert_difference("Page.count", 1) do
      post pages_url, params: { page: { title: "新ページ", body: "本文 [[他]]", tag_names: "ruby" } }
    end
    page = Page.find_by(title: "新ページ")
    assert_equal "本文 [[他]]", page.current_revision.body
    assert_redirected_to page_url(page)
  end

  test "show renders current revision body" do
    login
    page = Page.create!(title: "表示", created_by: @user)
    PageRevisionCreator.call(page: page, body: "# 見出し", author: @user)
    get page_url(page)
    assert_response :success
    assert_select "h1", text: "見出し"
  end

  test "update creates a new revision" do
    login
    page = Page.create!(title: "更新", created_by: @user)
    PageRevisionCreator.call(page: page, body: "旧", author: @user)
    assert_difference("page.revisions.count", 1) do
      patch page_url(page), params: { page: { title: "更新", body: "新", tag_names: "" } }
    end
    assert_equal "新", page.reload.current_revision.body
  end

  test "create records page.created activity" do
    login
    assert_difference("Activity.where(action: 'page.created').count", 1) do
      post pages_url, params: { page: { title: "記録新規", body: "本文" } }
    end
  end

  test "update records page.edited activity" do
    login
    page = Page.create!(title: "記録更新", created_by: @user)
    PageRevisionCreator.call(page: page, body: "旧", author: @user)
    assert_difference("Activity.where(action: 'page.edited').count", 1) do
      patch page_url(page), params: { page: { title: page.title, body: "新" } }
    end
  end

  test "destroy records page.deleted activity with label" do
    login
    page = Page.create!(title: "記録削除", created_by: @user)
    assert_difference("Activity.where(action: 'page.deleted').count", 1) do
      delete page_url(page)
    end
    assert_equal "記録削除", Activity.where(action: "page.deleted").order(:id).last.subject_label
  end
end
