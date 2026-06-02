require "test_helper"

class ChronicleControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(email_address: "ch@example.com", password: "password123", name: "CH")
    post session_url, params: { email_address: @user.email_address, password: "password123" }
  end

  test "index requires login" do
    delete session_url
    get chronicle_url
    assert_redirected_to new_session_url
  end

  test "index lists dated articles oldest first and excludes undated" do
    Article.create!(title: "無日付", created_by: @user)
    Article.create!(title: "1990年の出来事", created_by: @user,
                    starts_at: Time.zone.local(1990), starts_precision: "year")
    Article.create!(title: "1980年の出来事", created_by: @user,
                    starts_at: Time.zone.local(1980), starts_precision: "year")
    get chronicle_url
    assert_response :success
    assert_select "li", text: /1980年の出来事/
    assert_select "li", text: /1990年の出来事/
    assert_select "li", text: /無日付/, count: 0
    body = @response.body
    assert body.index("1980年の出来事") < body.index("1990年の出来事"), "oldest first"
  end

  test "index shows fuzzy label and range" do
    Article.create!(title: "戦争", created_by: @user,
                    starts_at: Time.zone.local(1939, 9, 1), starts_precision: "day",
                    ends_at: Time.zone.local(1945, 8, 1), ends_precision: "month")
    get chronicle_url
    assert_select "li", text: /1939年9月1日 〜 1945年8月/
  end
end
