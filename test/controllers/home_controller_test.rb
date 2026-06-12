require "test_helper"

class HomeControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(email_address: "home@example.com", name: "H", provider: "discord", uid: "home-user")
    sign_in_as(@user)
  end

  test "requires login" do
    delete session_url
    get root_url
    assert_redirected_to new_session_url
  end

  test "shows dashboard sections" do
    Article.create!(title: "ダッシュ記事", created_by: @user, status: "stub")
    get root_url
    assert_response :success
    assert_select "h2", text: /最近更新された記事/
    assert_select "h2", text: /加筆を求む/
    assert_select "h2", text: /最近の動き/
    assert_select ".dashboard-stats"
    assert_select "a", text: /ダッシュ記事/
  end

  test "stats include the total transcribed characters" do
    m = Material.new(user: @user, title: "統計音声")
    m.file.attach(io: StringIO.new("x"), filename: "s.mp3", content_type: "audio/mpeg")
    m.save!
    Transcription.create!(material: m, author: @user, body: "あ" * 1234, status: "drafting")
    get root_url
    assert_select ".dashboard-stats", text: /1,234.*文字起こし済/m
  end

  test "shows my personal streak line when I have activity" do
    ActivityRecorder.record(actor: @user, action: "tag.created", subject_label: "今日の活動")
    get root_url
    assert_select ".my-streak", text: /1.*日連続活動中.*最長.*1.*累計.*1/m
  end

  test "renders relative timestamps as auto-updating local-time elements" do
    article = Article.create!(title: "時刻記事", created_by: @user, status: "stub")
    ActivityRecorder.record(actor: @user, action: "article.created", subject: article)
    get root_url
    assert_response :success
    # 最近更新された記事 と 最近の動き の両方に time-ago 要素が出る
    assert_select "time[data-local=?]", "time-ago", minimum: 2
  end
end
