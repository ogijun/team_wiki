require "test_helper"

class ActivitiesHelperTest < ActionView::TestCase
  include ApplicationHelper # activity_icon が icon() に依存（実ビューでは全ヘルパーが mix される）
  setup do
    @user = User.create!(email_address: "h@example.com", password: "password123", name: "Hana")
  end

  test "phrase for article.created includes label" do
    a = Activity.new(user: @user, action: "article.created", subject_label: "ホーム")
    assert_equal "が記事「ホーム」を作成しました", activity_phrase(a)
  end

  test "phrase for user.joined has no label" do
    a = Activity.new(user: @user, action: "user.joined")
    assert_equal "が参加しました", activity_phrase(a)
  end

  test "actor: false drops the leading が (subject implied by context)" do
    a = Activity.new(user: @user, action: "article.edited", subject_label: "対象")
    assert_equal "記事「対象」を編集しました", activity_phrase(a, actor: false)
    joined = Activity.new(user: @user, action: "user.joined")
    assert_equal "参加しました", activity_phrase(joined, actor: false)
  end

  test "phrase for comment.posted references the subject label" do
    a = Activity.new(user: @user, action: "comment.posted", subject_label: "対象")
    assert_equal "が「対象」にコメントしました", activity_phrase(a)
  end

  test "phrase for article.created with nil label omits label" do
    a = Activity.new(user: @user, action: "article.created", subject_label: nil)
    assert_equal "が記事を作成しました", activity_phrase(a)
  end

  test "phrase links the live subject label and shows it only once" do
    article = Article.create!(title: "リンク記事", created_by: @user)
    a = Activity.new(user: @user, action: "article.edited", subject: article, subject_label: article.title)
    html = activity_phrase(a)
    assert_includes html, "を編集しました"
    assert_match %r{<a [^>]*>リンク記事</a>}, html
    assert_equal 1, html.scan("リンク記事").size
  end

  test "phrase for a deleted subject keeps the label as plain text" do
    a = Activity.new(user: @user, action: "article.deleted", subject: nil, subject_label: "消えた記事")
    html = activity_phrase(a)
    assert_includes html, "「消えた記事」を削除しました"
    assert_no_match %r{<a }, html
  end

  # action の追加時に表示文言の追加を忘れると沈黙の汎用フォールバックに落ちるのを防ぐ。
  test "every Activity action has a display phrase" do
    assert_equal Activity::ACTIONS.sort, ActivitiesHelper::PHRASES.keys.sort
  end

  test "every Activity action has a timeline icon" do
    assert_equal Activity::ACTIONS.sort, ActivitiesHelper::ICONS.keys.sort
  end

  test "activity_icon renders the mapped sprite symbol" do
    a = Activity.new(user: @user, action: "comment.posted", subject_label: "x")
    assert_includes activity_icon(a), "#message-circle"
    assert_includes activity_icon(a), "timeline__icon"
  end

  test "subject group merges verbs into 作成・編集 with a single linked title" do
    article = Article.create!(title: "まとめ記事", created_by: @user)
    a1 = Activity.new(user: @user, action: "article.created", subject: article, subject_label: article.title)
    a2 = Activity.new(user: @user, action: "article.edited",  subject: article, subject_label: article.title)
    group = ActivityGrouper::Group.new(kind: :subject, activities: [ a2, a1 ]) # 降順
    html = activity_group_phrase(group)
    assert_includes html, "記事"
    assert_includes html, "を作成・編集しました"
    assert_match %r{<a [^>]*>まとめ記事</a>}, html
    assert_equal 1, html.scan("まとめ記事").size
  end

  test "action group shows first 2 names plus an expandable ほかN件" do
    mats = Array.new(5) { |k| Material.create!(user: @user, url: "https://e.test/#{k}", title: "資料#{k}") }
    acts = mats.map { |m| Activity.new(user: @user, action: "material.added", subject: m, subject_label: m.title) }
    group = ActivityGrouper::Group.new(kind: :action, activities: acts.reverse) # 降順
    html = activity_group_phrase(group)
    assert_includes html, "を追加しました"
    assert_includes html, "ほか3件"
    assert_includes html, 'data-controller="disclosure"'
    assert_includes html, 'data-disclosure-target="rest"'
    assert_includes html, "hidden"
    assert_includes html, "資料0"   # 先頭は常時表示
    assert_includes html, "資料4"   # 残りも DOM 内には存在（隠れているだけ）
    # 資料0 は隠しスパンの外（常時表示）にある＝先頭2件と残りの分割が正しい
    assert_no_match %r{<span[^>]*hidden[^>]*>.*資料0}m, html
  end

  test "single group falls back to the existing per-activity phrase" do
    a = Activity.new(user: @user, action: "comment.posted", subject_label: "対象")
    group = ActivityGrouper::Group.new(kind: :single, activities: [ a ])
    assert_equal activity_phrase(a), activity_group_phrase(group)
  end

  # 不変条件: ActivityGrouper が :subject グループに通す noun（MERGEABLE_SETS 由来）は、
  # 必ず MERGE_NOUNS に描画エントリを持つ。これが破れると subject_group_phrase の
  # MERGE_NOUNS.fetch が実行時に KeyError になるため、テストで先に検出する。
  test "every mergeable-set noun has a MERGE_NOUNS rendering entry" do
    nouns = ActivityGrouper::MERGEABLE_SETS.flatten.map { |a| a.split(".").first }.uniq
    missing = nouns - ActivitiesHelper::MERGE_NOUNS.keys
    assert_empty missing, "MERGE_NOUNS rendering entry missing for: #{missing.inspect}"
  end

  test "subject group with actor: false drops the leading が" do
    article = Article.create!(title: "無主語記事", created_by: @user)
    a1 = Activity.new(user: @user, action: "article.created", subject: article, subject_label: article.title)
    a2 = Activity.new(user: @user, action: "article.edited",  subject: article, subject_label: article.title)
    group = ActivityGrouper::Group.new(kind: :subject, activities: [ a2, a1 ])
    html = activity_group_phrase(group, actor: false)
    assert html.start_with?("記事"), "actor:false は先頭の「が」を落とす（記事…で始まる）"
    refute_includes html, "が記事"
  end
end
