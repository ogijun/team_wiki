require "test_helper"

class ActivitiesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(email_address: "ac@example.com", name: "AC", provider: "discord", uid: "act-user")
    sign_in_as(@user)
  end

  test "index requires login" do
    delete session_url
    get activities_url
    assert_redirected_to new_session_url
  end

  test "index lists activities newest first and survives deleted subject" do
    article = Article.create!(title: "生存", created_by: @user)
    Activity.record(actor: @user, action: "article.created", subject: article)
    Activity.record(actor: @user, action: "article.deleted", subject_label: "消えた")
    article.destroy # 1件目の subject が dangling になる

    get activities_url
    assert_response :success
    assert_select "li", minimum: 2
    assert_select "li", text: /消えた/
  end

  test "home shows recent activity section" do
    Activity.record(actor: @user, action: "tag.created", subject_label: "最近タグ")
    get root_url
    assert_response :success
    assert_select "li", text: /最近タグ/
  end

  test "index renders the timeline" do
    Activity.create!(user: @user, action: "article.created", subject_label: "X")
    get activities_url
    assert_response :success
    assert_select "ul.timeline li"
  end

  test "a burst of same-action uploads collapses into one expandable line" do
    base = Time.current
    5.times do |k|
      m = Material.create!(user: @user, url: "https://e.test/b#{k}", title: "一括#{k}")
      Activity.create!(user: @user, action: "material.added", subject: m,
                       subject_label: m.title, created_at: base - k.minutes)
    end
    get activities_url
    assert_response :success
    assert_select "ul.timeline > li", count: 1            # 5件が1行に圧縮
    assert_select "li .timeline-more", text: /ほか3件/     # 先頭ACTION_LIST_HEAD(=2)件＋残り3件
    assert_select "li [data-controller=disclosure]"
  end

  test "timeline shows the actor's avatar on each entry" do
    Activity.record(actor: @user, action: "tag.created", subject_label: "アバター確認")
    get activities_url
    assert_select ".timeline li .avatar"
  end
end
