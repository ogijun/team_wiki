require "test_helper"

class ArticlesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(email_address: "p@example.com", name: "P", provider: "discord", uid: "art-user")
    sign_in_as(@user)
  end

  test "show isolates delete in a danger zone, not the actions row" do
    article = Article.create!(title: "削除テスト", created_by: @user)
    article.revise!(body: "本文", author: @user)
    get article_url(article)
    assert_select ".danger-zone button", text: "削除"
    assert_select ".actions button", text: "削除", count: 0
  end

  test "index shows a friendly empty state when there are no articles" do
    Article.destroy_all
    get articles_url
    assert_select ".empty-state"
  end

  test "index requires login" do
    delete session_url
    get articles_url
    assert_redirected_to new_session_url
  end

  test "create makes article with first revision" do
    assert_difference("Article.count", 1) do
      post articles_url, params: { article: { title: "新記事", body: "本文 [[他]]", tag_names: "ruby" } }
    end
    article = Article.find_by(title: "新記事")
    assert_equal "本文 [[他]]", article.current_revision.body
    assert_redirected_to article_url(article)
    follow_redirect!
    assert_select ".toast-stack .flash--notice .flash__msg", text: "記事を作成しました。"
  end

  test "show renders current revision body" do
    article = Article.create!(title: "表示", created_by: @user)
    article.revise!(body: "# 見出し", author: @user)
    get article_url(article)
    assert_response :success
    assert_select "h1", text: "見出し"
  end

  test "create with blank body does not persist an orphan article" do
    assert_no_difference("Article.count") do
      post articles_url, params: { article: { title: "本文なし", body: "", tag_names: "" } }
    end
    assert_response :unprocessable_entity
  end

  test "create with malicious out-of-range date returns 422, not 500, and persists nothing" do
    assert_no_difference("Article.count") do
      post articles_url, params: { article: { title: "不正日付", body: "本文", tag_names: "",
                                              start_year: "2020", start_month: "99" } }
    end
    assert_response :unprocessable_entity
  end

  test "update with blank body keeps previous revision and re-renders" do
    article = Article.create!(title: "本文必須", created_by: @user)
    article.revise!(body: "元の本文", author: @user)
    assert_no_difference("article.revisions.count") do
      patch article_url(article), params: { article: { title: article.title, body: "", tag_names: "" } }
    end
    assert_response :unprocessable_entity
    assert_equal "元の本文", article.reload.current_revision.body
  end

  test "show displays fuzzy date and range when present" do
    article = Article.create!(title: "出来事", created_by: @user,
                              starts_at: Time.zone.local(1939, 9, 1), starts_precision: "day",
                              ends_at: Time.zone.local(1945, 8, 1), ends_precision: "month")
    article.revise!(body: "本文", author: @user)
    get article_url(article)
    assert_response :success
    assert_select ".when", text: /1939年9月1日 〜 1945年8月/
  end

  test "show omits date line when no date" do
    article = Article.create!(title: "日付なし", created_by: @user)
    article.revise!(body: "本文", author: @user)
    get article_url(article)
    assert_response :success
    assert_select ".when", count: 0
  end

  test "update creates a new revision" do
    article = Article.create!(title: "更新", created_by: @user)
    article.revise!(body: "旧", author: @user)
    assert_difference("article.revisions.count", 1) do
      patch article_url(article), params: { article: { title: "更新", body: "新", tag_names: "" } }
    end
    assert_equal "新", article.reload.current_revision.body
  end

  test "update changes the title" do
    article = Article.create!(title: "元タイトル", created_by: @user)
    article.revise!(body: "本文", author: @user)
    patch article_url(article), params: { article: { title: "新タイトル", body: "本文", tag_names: "" } }
    assert_equal "新タイトル", article.reload.title
  end

  test "create records article.created activity" do
    assert_difference("Activity.where(action: 'article.created').count", 1) do
      post articles_url, params: { article: { title: "記録新規", body: "本文" } }
    end
  end

  test "update records article.edited activity" do
    article = Article.create!(title: "記録更新", created_by: @user)
    article.revise!(body: "旧", author: @user)
    assert_difference("Activity.where(action: 'article.edited').count", 1) do
      patch article_url(article), params: { article: { title: article.title, body: "新" } }
    end
  end

  test "destroy records article.deleted activity with label" do
    article = Article.create!(title: "記録削除", created_by: @user)
    assert_difference("Activity.where(action: 'article.deleted').count", 1) do
      delete article_url(article)
    end
    assert_equal "記録削除", Activity.where(action: "article.deleted").order(:id).last.subject_label
  end

  test "create stores fuzzy start with year precision" do
    post articles_url, params: { article: {
      title: "年だけ", body: "x",
      start_year: "1979", start_month: "", start_day: "", start_hour: "", start_minute: ""
    } }
    a = Article.find_by(title: "年だけ")
    assert_equal "year", a.starts_precision
    assert_equal Time.zone.local(1979, 1, 1), a.starts_at
    assert_nil a.ends_at
  end

  test "create stores fuzzy range with day and month precision" do
    post articles_url, params: { article: {
      title: "期間", body: "x",
      start_year: "1939", start_month: "9", start_day: "1", start_hour: "", start_minute: "",
      end_year: "1945", end_month: "8", end_day: "", end_hour: "", end_minute: ""
    } }
    a = Article.find_by(title: "期間")
    assert_equal "day", a.starts_precision
    assert_equal Time.zone.local(1939, 9, 1), a.starts_at
    assert_equal "month", a.ends_precision
    assert_equal Time.zone.local(1945, 8, 1), a.ends_at
  end

  test "update can set fuzzy date" do
    article = Article.create!(title: "あとで日付", created_by: @user)
    article.revise!(body: "本文", author: @user)
    patch article_url(article), params: { article: {
      title: article.title, body: "本文",
      start_year: "2000", start_month: "1", start_day: "", start_hour: "", start_minute: ""
    } }
    assert_equal "month", article.reload.starts_precision
    assert_equal Time.zone.local(2000, 1, 1), article.starts_at
  end

  test "show displays contributor avatars linking to users" do
    bob = User.create!(email_address: "bob2@example.com", name: "Bob", provider: "discord", uid: "art-bob")
    article = Article.create!(title: "貢献者表示", created_by: @user)
    article.revise!(body: "1", author: @user)
    article.revise!(body: "2", author: bob)
    get article_url(article)
    assert_response :success
    assert_select ".page-meta .contributors a[href=?]", user_path(@user)
    assert_select ".page-meta .contributors a[href=?]", user_path(bob)
  end

  test "show renders citations section linking to materials" do
    material = Material.create!(user: @user, url: "https://example.com/src", title: "出典資料")
    article = Article.create!(title: "引用あり", created_by: @user)
    article.revise!(body: "主張[[ref:#{material.slug}]]", author: @user)
    get article_url(article)
    assert_response :success
    assert_select "sup.ref a", text: "[1]"
    assert_select "section.citations ol li#ref-1 a", text: "出典資料"
  end

  test "show marks broken citation" do
    article = Article.create!(title: "壊れ引用", created_by: @user)
    article.revise!(body: "主張[[ref:nosuch99]]", author: @user)
    get article_url(article)
    assert_response :success
    assert_select "sup.ref-broken"
    assert_select "section.citations", count: 0
  end

  test "create persists kind and status" do
    post articles_url, params: { article: {
      title: "種別付き", body: "本文", kind: "work", status: "writing"
    } }
    article = Article.find_by(title: "種別付き")
    assert_equal "work", article.kind
    assert_equal "writing", article.status
  end

  test "update without status param preserves existing status" do
    article = Article.create!(title: "完成済み", created_by: @user, status: "done")
    article.revise!(body: "本文", author: @user)
    patch article_url(article), params: { article: { title: "完成済み", body: "更新本文" } }
    assert_equal "done", article.reload.status
  end

  test "index shows a lead line under the h1 with the article count" do
    Article.create!(title: "リード記事", created_by: @user, status: "stub")
    get articles_url
    assert_select "div.page-lead", text: /1 本/
  end

  test "index filters by kind" do
    Article.create!(title: "作品A", created_by: @user, kind: "work", status: "done")
    Article.create!(title: "人物B", created_by: @user, kind: "person", status: "stub")
    get articles_url(kind: "work")
    assert_response :success
    assert_select "a", text: "作品A"
    assert_select "a", text: "人物B", count: 0
  end

  test "first_comment on create becomes the article's first comment" do
    assert_difference "Comment.count", 1 do
      post articles_url, params: { article: { title: "初コメ記事", body: "本文" }, first_comment: "最初の方針メモ" }
    end
    article = Article.find_by!(title: "初コメ記事")
    assert_equal "最初の方針メモ", article.comments.first.body
  end

  test "index uses the rows layout with a newspaper icon per article" do
    Article.create!(title: "行形式記事", created_by: @user)
    get articles_url
    assert_select "ul.rows li.row", minimum: 1
    assert_select ".row__main svg use[href*=newspaper]"
    assert_select ".row .meta"
  end

  test "index shows the comment count when present" do
    article = Article.create!(title: "コメント付き記事", created_by: @user)
    article.comments.create!(body: "x", author: @user)
    get articles_url
    assert_select "li .meta", text: /・1/
    assert_select "li .meta svg use[href*=?]", "message-circle"
  end

  test "concurrent edit is rejected instead of silently overwriting (optimistic lock)" do
    article = Article.create!(title: "元タイトル", created_by: @user)
    article.revise!(body: "初版本文", author: @user)
    stale_version = article.reload.lock_version # B が編集画面を開いた時点の版

    # A が先に保存して lock_version を上げる
    article.update!(title: "Aが変えたタイトル")
    assert_operator article.reload.lock_version, :>, stale_version

    # B は古い版をもとに保存しようとする → 後勝ちで上書きさせない
    patch article_url(article), params: { article: {
      title: "Bが変えたタイトル", body: "Bの本文", lock_version: stale_version
    } }

    assert_response :conflict
    assert_equal "Aが変えたタイトル", article.reload.title, "Bの後勝ちで上書きされない"
    assert_equal "初版本文", article.current_revision.body, "本文もBに上書きされない"
  end

  test "edit form carries lock_version so conflicts can be detected" do
    article = Article.create!(title: "版付き記事", created_by: @user)
    article.revise!(body: "本文", author: @user)
    get edit_article_url(article)
    assert_select "input[type=hidden][name='article[lock_version]']"
  end

  test "non-conflicting edit still saves normally" do
    article = Article.create!(title: "普通の編集", created_by: @user)
    article.revise!(body: "初版", author: @user)
    patch article_url(article), params: { article: {
      title: "更新後", body: "二版", lock_version: article.reload.lock_version
    } }
    assert_redirected_to article
    assert_equal "更新後", article.reload.title
  end
end
