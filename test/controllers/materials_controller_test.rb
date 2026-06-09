require "test_helper"

class MaterialsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(email_address: "mc@example.com", name: "MC", provider: "discord", uid: "mat-user")
    login
  end

  def login
    sign_in_as(@user)
  end

  def link_params(extra = {})
    { material: { url: "https://youtu.be/dQw4w9WgXcQ", title: "動画", tag_names: "ruby, rails" }.merge(extra) }
  end

  # minitest 6 に Object#stub が無いので、モジュールメソッドを一時的に差し替える。
  def stub_singleton(mod, method_name, value)
    original = mod.method(method_name)
    mod.define_singleton_method(method_name) { |*| value }
    yield
  ensure
    mod.define_singleton_method(method_name, original)
  end

  test "index requires login" do
    delete session_url
    get materials_url
    assert_redirected_to new_session_url
  end

  test "new form marks required and optional fields with badges" do
    get new_material_url
    assert_response :success
    assert_select ".field-badge--req", minimum: 1
    assert_select ".field-badge--opt", minimum: 1
  end

  test "index renders when logged in with a material" do
    Material.create!(user: @user, url: "https://example.com/a", title: "資料A")
    get materials_url
    assert_response :success
    assert_select "a", text: "資料A"
  end

  test "index shows a friendly empty state when there are no materials" do
    Material.destroy_all
    get materials_url
    assert_select ".empty-state"
  end

  test "index shows transcription status column instead of the citation tag" do
    media = Material.new(user: @user, title: "音声X")
    media.file.attach(io: StringIO.new("x"), filename: "a.mp3", content_type: "audio/mpeg")
    media.save!
    get materials_url
    assert_select "th", text: "文字起こし"
    assert_select "th", text: "引用", count: 0
    assert_select "td", text: /未着手/
  end

  test "index shows uploader as an avatar link with a name tooltip, plus 投稿日時 and 発行日 columns" do
    m = Material.create!(user: @user, url: "https://example.com/p", title: "資料P",
                         published_year: 2020, published_month: 3)
    get materials_url
    assert_response :success
    assert_select "a.sort-link", text: /By/
    assert_select "a.sort-link", text: /投稿日時/
    assert_select "a.sort-link", text: /発行日/
    # アップローダー欄は名前テキストではなくアイコン＋title 属性（tooltip）
    assert_select "table tbody a[title=?]", @user.name
    assert_select "table tbody a", text: @user.name, count: 0
    # 発行日が一覧に出る（FuzzyDate label）
    assert_select "td", text: /2020年3月/
  end

  test "timestamps display in JST" do
    m = Material.create!(user: @user, url: "https://example.com/tz", title: "TZ")
    assert_equal "+09:00", m.created_at.formatted_offset
  end

  test "material detail shows the preview placeholder" do
    m = Material.create!(user: @user, url: "https://example.com/a", title: "資料A")
    get material_url(m)
    assert_select ".placeholder"
  end

  test "show isolates delete in a danger zone, not the actions row" do
    m = Material.create!(user: @user, url: "https://example.com/d", title: "削除資料")
    get material_url(m)
    assert_select ".danger-zone button", text: "削除"
    assert_select ".actions button", text: "削除", count: 0
  end

  test "index json returns slug and title" do
    m = Material.create!(user: @user, url: "https://example.com/a", title: "資料A")
    get materials_url(format: :json)
    assert_response :success
    data = JSON.parse(@response.body)
    entry = data.find { |e| e["slug"] == m.slug }
    assert_equal "資料A", entry["title"]
  end

  test "create makes a link material with tags" do
    assert_difference("Material.count", 1) do
      post materials_url, params: link_params
    end
    m = Material.order(:id).last
    assert_equal "https://youtu.be/dQw4w9WgXcQ", m.url
    assert_equal %w[rails ruby], m.tags.pluck(:name).sort
    assert_redirected_to material_url(m)
  end

  test "creating a material auto-creates a stub article that cites it" do
    assert_difference("Article.count", 1) do
      post materials_url, params: link_params(title: "新資料Z")
    end
    material = Material.find_by!(title: "新資料Z")
    stub = material.citing_articles.first
    assert_equal "stub", stub.status
    assert_equal "新資料Z", stub.title
    assert_includes stub.current_revision.body, "[[ref:#{material.slug}]]"
  end

  test "create autofills title from filename (sans extension) when blank" do
    file = fixture_file_upload("example-photo.png", "image/png")
    assert_difference("Material.count", 1) do
      post materials_url, params: { material: { file: file } }
    end
    assert_equal "example-photo", Material.order(:id).last.title
  end

  test "create autofills title from og title for a (non-youtube) url when blank" do
    stub_singleton(OgTitleFetcher, :call, "取得したページ題名") do
      post materials_url, params: { material: { url: "https://example.com/page" } }
    end
    assert_equal "取得したページ題名", Material.order(:id).last.title
  end

  test "create autofills title from YouTube oEmbed for a youtube url when blank" do
    stub_singleton(YoutubeOembed, :title, "動画タイトル") do
      post materials_url, params: { material: { url: "https://www.youtube.com/watch?v=oxCt6HYg4bo" } }
    end
    assert_equal "動画タイトル", Material.order(:id).last.title
  end

  test "create falls back to the url as title when no title can be fetched" do
    stub_singleton(YoutubeOembed, :title, nil) do
      stub_singleton(OgTitleFetcher, :call, nil) do
        post materials_url, params: { material: { url: "https://example.com/no-title" } }
      end
    end
    assert_equal "https://example.com/no-title", Material.order(:id).last.title
  end

  test "create keeps a given title (autofill does not run, no fetch)" do
    # title があれば autofill は早期 return＝OgTitleFetcher は呼ばれない（外部取得なし）。
    post materials_url, params: { material: { url: "https://example.com/page", title: "手入力" } }
    assert_equal "手入力", Material.order(:id).last.title
  end

  test "create with neither file nor url re-renders" do
    assert_no_difference("Material.count") do
      post materials_url, params: { material: { title: "空" } }
    end
    assert_response :unprocessable_entity
  end

  test "destroy removes material" do
    m = Material.create!(user: @user, url: "https://example.com/a")
    assert_difference("Material.count", -1) do
      delete material_url(m)
    end
    assert_redirected_to materials_url
  end

  test "create records material.added activity" do
    assert_difference("Activity.where(action: 'material.added').count", 1) do
      post materials_url, params: link_params
    end
  end

  test "destroy records material.deleted activity with label" do
    m = Material.create!(user: @user, url: "https://example.com/a", title: "資料Z")
    assert_difference("Activity.where(action: 'material.deleted').count", 1) do
      delete material_url(m)
    end
    assert_equal "資料Z", Activity.where(action: "material.deleted").order(:id).last.subject_label
  end

  test "material page lists articles that cite it" do
    m = Material.create!(user: @user, url: "https://example.com/d", title: "出典資料")
    article = Article.create!(title: "引用する記事", created_by: @user)
    ArticleRevisionCreator.call(article: article, body: "本文[[ref:#{m.slug}]]", author: @user)
    get material_url(m)
    assert_response :success
    assert_select "a", text: "引用する記事"
  end

  test "index paginates with per param" do
    30.times { |i| Material.create!(user: @user, url: "https://example.com/#{i}", title: "M#{i}") }
    get materials_url(per: 25)
    assert_response :success
    assert_select "table.materials-table tbody tr", count: 25
    get materials_url(per: 50)
    assert_select "table.materials-table tbody tr", minimum: 26
  end

  test "index sorts by name ascending" do
    Material.create!(user: @user, url: "https://example.com/b", title: "Bravo")
    Material.create!(user: @user, url: "https://example.com/a", title: "Alpha")
    get materials_url(sort: "name", dir: "asc")
    assert_response :success
    body = @response.body
    assert body.index("Alpha") < body.index("Bravo"), "Alpha should come before Bravo"
  end

  test "index sorts by created_at desc by default" do
    Material.create!(user: @user, url: "https://example.com/old", title: "OLDONE")
    Material.create!(user: @user, url: "https://example.com/new", title: "NEWONE")
    get materials_url
    body = @response.body
    assert body.index("NEWONE") < body.index("OLDONE"), "newest first by default"
  end

  test "index ignores invalid sort and per" do
    Material.create!(user: @user, url: "https://example.com/x", title: "X")
    get materials_url(sort: "title); DROP TABLE", dir: "sideways", per: "9999")
    assert_response :success
  end

  test "index json stays unpaginated full list" do
    30.times { |i| Material.create!(user: @user, url: "https://example.com/j#{i}", title: "J#{i}") }
    get materials_url(format: :json, per: 25)
    data = JSON.parse(@response.body)
    assert_operator data.size, :>=, 30
  end

  test "index json includes thumb_url for youtube and null for plain link" do
    yt = Material.create!(user: @user, url: "https://youtu.be/dQw4w9WgXcQ", title: "動画")
    plain = Material.create!(user: @user, url: "https://example.com/page", title: "ページ")
    get materials_url(format: :json)
    data = JSON.parse(@response.body)
    yt_entry = data.find { |e| e["slug"] == yt.slug }
    plain_entry = data.find { |e| e["slug"] == plain.slug }
    assert_match "img.youtube.com/vi/dQw4w9WgXcQ", yt_entry["thumb_url"]
    assert_nil plain_entry["thumb_url"]
  end

  test "create persists bibliographic fields and year-only published date" do
    post materials_url, params: { material: {
      url: "https://x.test/a", source: "サンプル誌", author: "サンプル著者",
      memo: "自由メモ", published_year: "1998", published_month: "", published_day: ""
    } }
    m = Material.order(:created_at).last
    assert_equal "サンプル誌", m.source
    assert_equal "サンプル著者", m.author
    assert_equal "自由メモ", m.memo
    assert_equal "year", m.published_precision
    assert_equal 1998, m.published_at.year
  end

  test "create persists confidence and rights" do
    @user.update!(role: "admin")
    post materials_url, params: { material: {
      url: "https://x.test/c", confidence: "confirmed", rights: "quotable"
    } }
    m = Material.order(:created_at).last
    assert_equal "confirmed", m.confidence
    assert_equal "quotable", m.rights
  end

  test "index sorts by type (link/file grouping) without error" do
    Material.create!(user: @user, url: "https://example.com/a", title: "L")
    img = Material.new(user: @user)
    img.file.attach(io: StringIO.new("x"), filename: "f.png", content_type: "image/png")
    img.save!
    get materials_url(sort: "type")
    assert_response :success
  end

  test "source url is locked after create, metadata still editable" do
    m = Material.create!(user: @user, url: "https://x.test/orig")
    patch material_url(m), params: { material: { url: "https://x.test/changed", title: "新タイトル" } }
    m.reload
    assert_equal "https://x.test/orig", m.url
    assert_equal "新タイトル", m.title
  end

  test "edit form does not expose file or url inputs" do
    m = Material.create!(user: @user, url: "https://x.test/orig")
    get edit_material_url(m)
    assert_response :success
    assert_select "input[name=?]", "material[url]", count: 0
    assert_select "input[name=?]", "material[file]", count: 0
  end

  test "editor cannot change confidence (ignored)" do
    m = Material.create!(user: @user, url: "https://x.test/e", confidence: "unconfirmed")
    patch material_url(m), params: { material: { url: "https://x.test/e", confidence: "confirmed" } }
    assert_equal "unconfirmed", m.reload.confidence
  end

  test "admin can change confidence" do
    @user.update!(role: "admin")
    m = Material.create!(user: @user, url: "https://x.test/a2", confidence: "unconfirmed")
    patch material_url(m), params: { material: { url: "https://x.test/a2", confidence: "confirmed" } }
    assert_equal "confirmed", m.reload.confidence
  end

  test "media material shows a transcription section" do
    m = Material.new(user: @user, title: "音声")
    m.file.attach(io: StringIO.new("x"), filename: "a.mp3", content_type: "audio/mpeg")
    m.save!
    get material_url(m)
    assert_select "a[href=?]", edit_material_transcription_path(m)
  end

  test "non-media material has no transcription section" do
    link = Material.create!(user: @user, title: "外部", url: "https://example.com/x")
    get material_url(link)
    assert_select "a[href=?]", edit_material_transcription_path(link), count: 0
  end
end
