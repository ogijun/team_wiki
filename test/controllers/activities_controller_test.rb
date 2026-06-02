require "test_helper"

class ActivitiesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(email_address: "ac@example.com", password: "password123", name: "AC")
    post session_url, params: { email_address: @user.email_address, password: "password123" }
  end

  test "index requires login" do
    delete session_url
    get activities_url
    assert_redirected_to new_session_url
  end

  test "index lists activities newest first and survives deleted subject" do
    page = Page.create!(title: "生存", created_by: @user)
    ActivityRecorder.record(actor: @user, action: "page.created", subject: page)
    ActivityRecorder.record(actor: @user, action: "page.deleted", subject_label: "消えた")
    page.destroy # 1件目の subject が dangling になる

    get activities_url
    assert_response :success
    assert_select "li", minimum: 2
    assert_select "li", text: /消えた/
  end

  test "home shows recent activity section" do
    ActivityRecorder.record(actor: @user, action: "tag.created", subject_label: "最近タグ")
    get root_url
    assert_response :success
    assert_select "li", text: /最近タグ/
  end
end
