require "test_helper"

class StatsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(email_address: "stc@example.com", name: "STC", provider: "discord", uid: "stats-u")
    sign_in_as(@user)
  end

  test "index requires login" do
    delete session_url
    get stats_url
    assert_redirected_to new_session_url
  end

  test "index renders sparkline charts from snapshots" do
    StatSnapshot.create!(date: Date.current - 1, articles_count: 3, materials_count: 5,
                         unconfirmed_materials_count: 2, transcribed_chars: 100)
    StatSnapshot.create!(date: Date.current, articles_count: 4, materials_count: 6,
                         unconfirmed_materials_count: 1, transcribed_chars: 1500)
    get stats_url
    assert_response :success
    assert_select "svg polyline", minimum: 4
    assert_select ".stat-chart", text: /1,500/
  end

  test "index shows an empty state before the first snapshot" do
    get stats_url
    assert_select ".empty-state"
  end

  test "renders all stat charts including storage and pages" do
    StatSnapshot.capture!
    get stats_url
    assert_response :success
    assert_select ".stat-chart", count: 6
    assert_select ".stat-chart__head", text: /保存容量/
    assert_select ".stat-chart__head", text: /総ページ数/
  end
end
