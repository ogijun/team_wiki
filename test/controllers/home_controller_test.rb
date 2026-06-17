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
    assert_select ".home-hero__sum"
    assert_select "a", text: /ダッシュ記事/
  end

  test "pages without content_for(:aside) do not render an empty right-sidebar landmark" do
    get root_url
    assert_select "aside.sidebar-right", count: 0
  end

  test "hero offers the primary create/transcribe actions as buttons" do
    get root_url
    assert_response :success
    assert_select ".home-hero__cta a[href=?]", new_article_path, text: /記事を書く/
    assert_select ".home-hero__cta a[href=?]", new_material_path, text: /資料を追加/
    assert_select ".home-hero__cta a[href=?]", transcriptions_path, text: /文字起こし/
  end

  test "hero headline shows the brand" do
    get root_url
    assert_select "h1.home-hero__brand"
  end

  test "hero shows the site tagline when set" do
    SiteSetting.instance.update!(tagline: "一次資料を集め、整理し、後世に活用する。")
    get root_url
    assert_select ".home-hero__tagline", text: "一次資料を集め、整理し、後世に活用する。"
  end

  test "hero omits the tagline element when unset" do
    SiteSetting.instance.update!(tagline: nil)
    get root_url
    assert_select ".home-hero__tagline", count: 0
  end

  test "home collapses a long same-user activity run into a +N summary and fills the feed with others" do
    # 同一ユーザの連続を多数作る（>30分間隔で別グループに）＋ 別ユーザの活動も。
    base = Time.zone.local(2026, 6, 15, 12, 0)
    6.times { |i| Activity.create!(user: @user, action: "comment.posted", subject_label: "C#{i}", created_at: base - (i * 40).minutes) }
    other = User.create!(email_address: "o@example.com", name: "Other", provider: "discord", uid: "o-user")
    Activity.create!(user: other, action: "tag.created", subject_label: "T", created_at: base - 300.minutes)

    get root_url
    assert_response :success
    # 先頭2つの後に「ほかN件」の要約行が出る
    assert_select ".timeline__overflow", text: /ほか.*件/
    # 畳んだぶん他ユーザの活動が繰り上がって表示される
    assert_select ".timeline a", text: /Other/
  end

  test "home shows the site-wide activity heatmap" do
    Activity.create!(user: @user, action: "article.created")
    get root_url
    assert_response :success
    assert_select ".activity-block .heatmap"
    assert_select ".activity-block .hourly"
  end

  test "stats trends link is an accessible icon-only link" do
    get root_url
    # アイコンのみ＝可視テキストは無いが、リンク名は aria-label で読み上げ可能
    assert_select ".home-hero__sum a[href=?][aria-label=?]", stats_path, "統計の推移"
    assert_select ".home-hero__sum a[href=?] svg", stats_path
  end

  test "stats include the total transcribed characters" do
    m = Material.new(user: @user, title: "統計音声")
    m.file.attach(io: StringIO.new("x"), filename: "s.mp3", content_type: "audio/mpeg")
    m.save!
    Transcription.create!(material: m, author: @user, body: "あ" * 1234, status: "drafting")
    get root_url
    assert_select ".home-hero__sum", text: /1,234.*文字起こし済/m
  end

  test "shows my personal streak line when I have activity" do
    Activity.record(actor: @user, action: "tag.created", subject_label: "今日の活動")
    get root_url
    assert_select ".my-streak", text: /1.*日連続活動中.*最長.*1.*累計.*1/m
  end

  test "renders relative timestamps as auto-updating local-time elements" do
    article = Article.create!(title: "時刻記事", created_by: @user, status: "stub")
    Activity.record(actor: @user, action: "article.created", subject: article)
    get root_url
    assert_response :success
    # 最近更新された記事 と 最近の動き の両方に time-ago 要素が出る
    assert_select "time[data-local=?]", "time-ago", minimum: 2
  end
end
