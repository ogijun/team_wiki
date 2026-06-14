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

  test "index renders trend bar charts from snapshots" do
    StatSnapshot.create!(date: Date.current - 1, articles_count: 3, materials_count: 5,
                         unconfirmed_materials_count: 2, transcribed_chars: 100)
    StatSnapshot.create!(date: Date.current, articles_count: 4, materials_count: 6,
                         unconfirmed_materials_count: 1, transcribed_chars: 1500)
    get stats_url
    assert_response :success
    # 2スナップショット × 6指標 = 12本（0基準の縦棒）。x軸ラベル(.trend__xaxis)も出る。
    assert_select ".stat-chart .trend__bar", minimum: 12
    assert_select ".stat-chart .trend__xaxis"
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

  test "renders the site-wide heatmap and hourly graph plus per-type panels" do
    Activity.create!(user: @user, action: "article.created")
    get stats_url
    assert_response :success
    assert_select ".activity-block .heatmap"              # 全体の草マップ
    assert_select ".activity-block .hourly"               # 全体の時間帯
    assert_select ".stat-multiples .stat-panel", count: 5 # 種類別パネル5つ
  end
end
