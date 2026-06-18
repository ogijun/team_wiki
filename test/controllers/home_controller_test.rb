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

  test "home shows the materials-first 2-column body (report feed + help-wanted materials)" do
    media = Material.new(user: @user, title: "未完成サンプル音声")
    media.file.attach(io: StringIO.new("x"), filename: "s.mp3", content_type: "audio/mpeg")
    media.save!
    get root_url
    assert_response :success
    assert_select "h2", text: /報告します/
    assert_select "h2", text: /この続き、誰かお願い/
    # 右カラムに未完成資料が出て、「すべての未完成資料を表示」が進捗ボードへ
    assert_select "a", text: /未完成サンプル音声/
    assert_select "a[href=?]", transcriptions_path, text: /すべての未完成資料を表示/
    # 廃止: 最近更新された記事 / 加筆を求む の見出しは出ない
    assert_select "h2", text: /最近更新された記事/, count: 0
    assert_select "h2", text: /加筆を求む/, count: 0
  end

  test "pages without content_for(:aside) do not render an empty right-sidebar landmark" do
    get root_url
    assert_select "aside.sidebar-right", count: 0
  end

  test "hero CTA is materials-first: 資料を追加する / 文字起こしをする (no 記事を書く)" do
    get root_url
    assert_response :success
    assert_select ".home-hero__cta a[href=?]", new_material_path, text: /資料を追加する/
    assert_select ".home-hero__cta a[href=?]", transcriptions_path, text: /文字起こし/
    assert_select ".home-hero__cta a[href=?]", new_article_path, count: 0
  end

  test "home shows the configured heading as a visible h1" do
    SiteSetting.instance.update!(home_heading: "アーカイブ計画")
    get root_url
    assert_select "h1.home-hero__heading", text: "アーカイブ計画"
    assert_select "h1.sr-only", count: 0
  end

  test "home falls back to a visually-hidden heading when home_heading is unset" do
    # 見出し未設定でも文書構造のため h1 は残し、視覚的には隠す（.sr-only）。
    # ブランド名はトップバーに出ているのでヒーローでは繰り返さない。
    SiteSetting.instance.update!(home_heading: nil)
    get root_url
    assert_select "h1.sr-only"
    assert_select "h1.home-hero__heading", count: 0
    assert_select "h1.home-hero__brand", count: 0
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

  test "summary shows 資料 / 文字起こし済 / 未完成資料 and not 記事 / 未確認資料" do
    m = Material.new(user: @user, title: "統計音声")
    m.file.attach(io: StringIO.new("x"), filename: "s.mp3", content_type: "audio/mpeg")
    m.save!
    Transcription.create!(material: m, author: @user, body: "あ" * 1234, status: "drafting")
    get root_url
    assert_select ".home-hero__sum", text: /1,234.*文字起こし済/m
    assert_select ".home-hero__sum", text: /未完成資料/
    assert_select ".home-hero__sum", text: /記事/, count: 0
    assert_select ".home-hero__sum", text: /未確認資料/, count: 0
  end

  test "does not show a personal streak line on the home page" do
    Activity.record(actor: @user, action: "tag.created", subject_label: "今日の活動")
    get root_url
    assert_select ".my-streak", count: 0
  end

  test "renders relative timestamps as auto-updating local-time elements" do
    article = Article.create!(title: "時刻記事", created_by: @user, status: "stub")
    Activity.record(actor: @user, action: "article.created", subject: article)
    get root_url
    assert_response :success
    # 活動フィード「報告します！」に time-ago 要素が出る
    assert_select "time[data-local=?]", "time-ago", minimum: 1
  end

  test "sidebar is materials-first and demotes 記事 to (見直し中) below a divider" do
    get root_url
    # コンテンツ群に 資料/文字起こし/タグ/年表 が出る
    assert_select ".sidebar__nav a[href=?]", materials_path
    assert_select ".sidebar__nav a[href=?]", transcriptions_path
    assert_select ".sidebar__nav a[href=?]", tags_path
    assert_select ".sidebar__nav a[href=?]", chronicle_path
    # 記事は降格: (見直し中) マーカー付き＋区切り線あり
    assert_select ".sidebar__nav a[href=?] small.wip", articles_path, text: /見直し中/
    assert_select ".sidebar__nav .nav-sep"
  end
end
