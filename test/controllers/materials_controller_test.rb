require "test_helper"

class MaterialsControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    @user = User.create!(email_address: "mc@example.com", name: "MC", provider: "discord", uid: "mat-user")
    login
  end

  def login
    sign_in_as(@user)
  end

  def link_params(extra = {})
    { material: { url: "https://example.com/v1", title: "動画", tag_names: "ruby, rails" }.merge(extra) }
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

  test "create enqueues the post-process job" do
    file = Rack::Test::UploadedFile.new(
      Rails.root.join("test/fixtures/files/example-photo.png"), "image/png"
    )
    assert_enqueued_with(job: MaterialPostProcessJob) do
      post materials_url, params: { material: { title: "画像資料", file: file } }
    end
  end

  test "show displays page_count in the bibliography when present" do
    m = Material.create!(user: @user, url: "https://x.test/book", title: "本", page_count: 300)
    get material_url(m)
    assert_select ".bibliography dt", text: "総ページ数"
    assert_select ".bibliography dd", text: /300/
  end

  test "edit form has an editable page_count field and update persists it" do
    m = Material.create!(user: @user, url: "https://x.test/book2", title: "本2")
    get edit_material_url(m)
    assert_select "input[name='material[page_count]']"
    patch material_url(m), params: { material: { page_count: 42 } }
    assert_equal 42, m.reload.page_count
  end

  test "index renders when logged in with a material" do
    Material.create!(user: @user, url: "https://example.com/a", title: "資料A")
    get materials_url
    assert_response :success
    assert_select "a", text: "資料A"
  end

  test "index table is wrapped in a horizontal-scroll container (mobile)" do
    Material.create!(user: @user, url: "https://x.test/scroll", title: "スクロール資料")
    get materials_url
    assert_select ".table-scroll table.materials-table"
  end

  test "index shows the library summary band" do
    create(:material, :with_pdf)
    get materials_url
    assert_select ".library-summary"
  end

  test "index hides the library summary band when filtering by tag" do
    m = create(:material, :with_pdf)
    m.update!(tag_names: "ruby")
    get materials_url(tag: m.tags.first.slug)
    assert_select ".library-summary", false
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

  test "pdf material: filename opens an overlay dialog viewer; download is a separate icon link" do
    pdf = Material.new(user: @user, title: "PDF資料")
    pdf.file.attach(io: StringIO.new("%PDF-1.4"), filename: "doc.pdf", content_type: "application/pdf")
    pdf.save!
    get material_url(pdf)
    assert_select "[data-controller=pdf][data-pdf-url-value=?]", pdf_material_path(pdf) do
      assert_select ".placeholder"                            # 既定はプレースホルダ表示
      assert_select "dialog.lightbox:not([open]) .pdf-viewer" # オーバーレイは閉じた状態
      assert_select "a[data-action='pdf#open']", text: /doc\.pdf/
      assert_select "a[href=?] svg use[href*=download]", rails_blob_path(pdf.file)
      assert_select "a[href=?][aria-label=?]", rails_blob_path(pdf.file), "ダウンロード" # アイコンのみDLリンクのアクセシブル名
    end
  end

  test "image material mirrors the overlay viewer + download-icon composition" do
    img = Material.new(user: @user, title: "画像資料V")
    img.file.attach(io: File.open(file_fixture("example-photo.png")), filename: "p.png", content_type: "image/png")
    img.save!
    get material_url(img)
    assert_select "[data-controller=viewer]" do
      assert_select "dialog.lightbox:not([open]) img"
      assert_select "a[data-action='viewer#open']", text: /p\.png/
      assert_select "a[href=?] svg use[href*=download]", rails_blob_path(img.file)
    end
  end

  test "material detail shows the preview placeholder only for non-previewable files" do
    doc = Material.new(user: @user, title: "DOCX資料")
    doc.file.attach(io: StringIO.new("x"), filename: "d.docx",
                    content_type: "application/vnd.openxmlformats-officedocument.wordprocessingml.document")
    doc.save!
    get material_url(doc)
    assert_select ".placeholder"

    link = Material.create!(user: @user, url: "https://example.com/a", title: "リンク資料")
    get material_url(link)
    assert_select ".placeholder", count: 0
  end

  test "material detail is organized into zones; empty zones are absorbed by the progress strip" do
    m = Material.create!(user: @user, url: "https://example.com/zone", title: "ゾーン資料")
    get material_url(m)
    assert_select ".progress-strip"
    assert_select "h2", text: "記事で使う"
    assert_select "h2", text: /コメント/
    # 空の書誌ゾーン・空の被引用見出しは出さない（状態はストリップが担う）
    assert_select ".bibliography-section", count: 0
    assert_select "h3", text: "この資料を引用している記事", count: 0
  end

  test "progress strip shows pending steps as action links" do
    m = Material.create!(user: @user, url: "https://example.com/strip", title: "ストリップ資料")
    get material_url(m)
    # 書誌なし→追記リンク / 原本未確認(非admin)はテキスト / 未引用→引用タグへのアンカー
    assert_select ".progress-strip a[href=?]", edit_material_path(m), text: /書誌を追記/
    assert_select ".progress-strip", text: /原本未確認/
    assert_select ".progress-strip a[href=?]", "#usage", text: /引用タグを使う/
  end

  test "progress strip shows completed steps as checks" do
    m = Material.create!(user: @user, url: "https://example.com/done", title: "完了資料",
                         source: "サンプル誌", confidence: "confirmed")
    article = Article.create!(title: "引用元記事", created_by: @user)
    ArticleRevisionCreator.call(article: article, body: "[[ref:#{m.slug}]]", author: @user)
    get material_url(m)
    assert_select ".progress-strip .strip-step--done", text: /書誌/
    assert_select ".progress-strip .strip-step--done", text: /原本確認済/
    assert_select ".progress-strip .strip-step--done", text: /引用 1件/
  end

  test "transcribable material without a transcription shows a clear 作成 CTA in the usage zone" do
    media = Material.new(user: @user, title: "未起こし音声")
    media.file.attach(io: StringIO.new("x"), filename: "c.mp3", content_type: "audio/mpeg")
    media.save!
    get material_url(media)
    assert_select ".usage a[role=button][href=?]", edit_material_transcription_path(media), text: "文字起こしを作成"
  end

  test "progress strip includes transcription state for every material, including links" do
    media = Material.new(user: @user, title: "音声S")
    media.file.attach(io: StringIO.new("x"), filename: "s.mp3", content_type: "audio/mpeg")
    media.save!
    get material_url(media)
    assert_select ".progress-strip a[href=?]", edit_material_transcription_path(media), text: /文字起こし/

    link = Material.create!(user: @user, url: "https://example.com/nt", title: "リンクNT")
    get material_url(link)
    assert_select ".progress-strip a[href=?]", edit_material_transcription_path(link), text: /文字起こし/
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
    assert_equal "https://example.com/v1", m.url
    assert_equal %w[rails ruby], m.tags.pluck(:name).sort
    assert_redirected_to material_url(m)
  end

  test "first_comment on create becomes the material's first comment with no separate activity" do
    assert_difference "Comment.count", 1 do
      assert_no_difference "Activity.where(action: 'comment.posted').count" do
        post materials_url, params: link_params(title: "初コメ資料").merge(first_comment: "最初のメモ")
      end
    end
    m = Material.find_by!(title: "初コメ資料")
    assert_equal "最初のメモ", m.comments.first.body
    assert_equal 1, m.comments_count
  end

  test "index shows the comment count when present" do
    m = Material.create!(user: @user, url: "https://example.com/cc", title: "コメント資料CC")
    m.comments.create!(body: "x", author: @user)
    get materials_url
    assert_select "td .muted svg use[href*=?]", "message-circle"
    assert_select "td .muted", text: /1/
  end

  test "create stores the extracted file date and posts a candidates comment" do
    extracted = { file_created_at: Time.zone.local(2020, 3, 16, 10, 0),
                  details: { "タイトル (PDF)" => "Sample Doc", "撮影日時 (EXIF)" => "2020年3月16日 10:00" } }
    file = fixture_file_upload("example-photo.png", "image/png")
    # 抽出は非同期化されたので、enqueue されたジョブをその場で実行して結果を検証する。
    stub_singleton(MaterialMetadataExtractor, :call, extracted) do
      perform_enqueued_jobs do
        post materials_url, params: { material: { file: file, title: "抽出資料" } }
      end
    end
    m = Material.find_by!(title: "抽出資料")
    assert_equal Time.zone.local(2020, 3, 16, 10, 0), m.file_created_at
    comment = m.comments.first
    assert_includes comment.body, "自動抽出"
    assert_includes comment.body, "タイトル (PDF): Sample Doc"

    get material_url(m)
    assert_select ".bibliography dt", text: "ファイル作成日"
    assert_select ".bibliography dd", text: /2020年3月16日/
  end

  test "create without extractable metadata adds neither date nor comment" do
    stub_singleton(MaterialMetadataExtractor, :call, { file_created_at: nil, details: {} }) do
      perform_enqueued_jobs do
        post materials_url, params: link_params(title: "抽出なし")
      end
    end
    m = Material.find_by!(title: "抽出なし")
    assert_nil m.file_created_at
    assert_equal 0, m.comments.count
  end

  test "creating a material with the checkbox creates a stub article that cites it" do
    assert_difference("Article.count", 1) do
      post materials_url, params: link_params(title: "新資料Z").merge(create_stub_article: "1")
    end
    material = Material.find_by!(title: "新資料Z")
    stub = material.citing_articles.first
    assert_equal "stub", stub.status
    assert_equal "新資料Z", stub.title
    assert_includes stub.current_revision.body, "[[ref:#{material.slug}]]"
  end

  test "creating a material without the checkbox does not create a stub article" do
    assert_no_difference("Article.count") do
      post materials_url, params: link_params(title: "スタブなし資料")
    end
  end

  test "checked stub article inherits the material's published fuzzy date" do
    post materials_url, params: { material: {
      url: "https://example.com/dated", title: "日付つき資料",
      published_year: "1991", published_month: "3", published_day: "16"
    }, create_stub_article: "1" }
    stub = Material.find_by!(title: "日付つき資料").citing_articles.first
    assert_equal Time.zone.local(1991, 3, 16), stub.starts_at
    assert_equal "day", stub.starts_precision
  end

  test "stub checkbox appears unchecked on new and not at all on edit" do
    get new_material_url
    assert_select "input[type=checkbox][name=create_stub_article]"
    assert_select "input[name=create_stub_article][checked]", count: 0

    m = Material.create!(user: @user, url: "https://example.com/e", title: "編集資料")
    get edit_material_url(m)
    assert_select "input[name=create_stub_article]", count: 0
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

  test "create autofills title from the video site api when blank" do
    stub_singleton(VideoMetadata, :call, { title: "動画タイトル", published_on: nil }) do
      post materials_url, params: { material: { url: "https://www.youtube.com/watch?v=oxCt6HYg4bo" } }
    end
    assert_equal "動画タイトル", Material.order(:id).last.title
  end

  test "create fills the blank published date from the video site api (day precision)" do
    stub_singleton(VideoMetadata, :call, { title: "DM動画", published_on: Date.new(2012, 10, 13) }) do
      post materials_url, params: { material: { url: "https://www.dailymotion.com/video/xualzi" } }
    end
    m = Material.order(:id).last
    assert_equal "DM動画", m.title
    assert_equal Time.zone.local(2012, 10, 13), m.published_at
    assert_equal "day", m.published_precision
  end

  test "user-entered published date wins over the video site date" do
    stub_singleton(VideoMetadata, :call, { title: "上書きしない", published_on: Date.new(2012, 10, 13) }) do
      post materials_url, params: { material: {
        url: "https://vimeo.com/838983799", title: "手動日付", published_year: "1991", published_month: "", published_day: ""
      } }
    end
    m = Material.find_by!(title: "手動日付")
    assert_equal 1991, m.published_at.year
    assert_equal "year", m.published_precision
  end

  test "create falls back to the url as title when no title can be fetched" do
    stub_singleton(VideoMetadata, :call, nil) do
      stub_singleton(OgTitleFetcher, :call, nil) do
        post materials_url, params: { material: { url: "https://example.com/no-title" } }
      end
    end
    assert_equal "https://example.com/no-title", Material.order(:id).last.title
  end

  test "create keeps a given title without fetching og title" do
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

  test "create persists the bibliographic detail fields and show displays them" do
    post materials_url, params: { material: {
      url: "https://x.test/bib2", title: "詳細書誌資料",
      isbn: "978-4-04-410103-3", pages: "pp.12-15", publisher: "サンプル書店", volume: "Vol.3"
    } }
    m = Material.find_by!(title: "詳細書誌資料")
    assert_equal "978-4-04-410103-3", m.isbn

    get material_url(m)
    assert_select ".bibliography dt", text: "ISBN"
    assert_select ".bibliography dd", text: "pp.12-15"
    assert_select ".bibliography dd", text: "サンプル書店"
    assert_select ".bibliography dd", text: "Vol.3"
  end

  test "create persists bibliographic fields and year-only published date" do
    post materials_url, params: { material: {
      url: "https://x.test/a", source: "サンプル誌", author: "サンプル著者",
      published_year: "1998", published_month: "", published_day: ""
    } }
    m = Material.order(:created_at).last
    assert_equal "サンプル誌", m.source
    assert_equal "サンプル著者", m.author
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

  test "every material, including a link, has a transcription section" do
    link = Material.create!(user: @user, title: "外部", url: "https://example.com/x")
    get material_url(link)
    assert_select "a[href=?]", edit_material_transcription_path(link)
  end
end
