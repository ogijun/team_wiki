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

  test "index date and status cells use nowrap classes to keep rows short" do
    Material.create!(user: @user, url: "https://x.test/short", title: "短行資料", published_year: 2020)
    get materials_url
    assert_select "td.col-when"   # 投稿日時/発行日（折返し制御）
    assert_select "td.col-status" # 文字起こし
    assert_select "td .cell-tags" # タグはチップを詰めて並べる
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

  test "index shows uploader as an avatar link with a name tooltip, plus 投稿日時 and 初出 columns" do
    m = Material.create!(user: @user, url: "https://example.com/p", title: "資料P",
                         published_year: 2020, published_month: 3)
    get materials_url
    assert_response :success
    assert_select "a.sort-link", text: /By/
    assert_select "a.sort-link", text: /投稿日時/
    assert_select "a.sort-link", text: /初出/
    # アップローダー欄は名前テキストではなくアイコン＋title 属性（tooltip）
    assert_select "table tbody a[title=?]", @user.name
    assert_select "table tbody a", text: @user.name, count: 0
    # 初出が一覧に出る（スラッシュ表記）
    assert_select "td", text: %r{2020/03}
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
      assert_select "input.pdf-viewer__pageinput[data-action=?]", "change->pdf#jump" # 番号入力でページジャンプ
      assert_select ".pdf-viewer > .pdf-viewer__resizer"                             # ダイアログ右下にリサイズグリップ
      assert_select "a[data-action='pdf#open']", text: /doc\.pdf/
      assert_select "a[href=?] svg use[href*=download]", rails_blob_path(pdf.file)
      assert_select "a[href=?][aria-label=?]", rails_blob_path(pdf.file), "ダウンロード" # アイコンのみDLリンクのアクセシブル名
    end
  end

  test "pdf viewer controls are icon buttons with tooltips" do
    pdf = Material.new(user: @user, title: "PDFアイコン操作")
    pdf.file.attach(io: StringIO.new("%PDF-1.4"), filename: "icons.pdf", content_type: "application/pdf")
    pdf.save!
    get material_url(pdf)
    # 前後/拡大縮小/フィット/閉じる は アイコン＋title(ツールチップ) のボタン
    assert_select ".pdf-viewer__bar button[data-action='pdf#prev'][title=?] svg use[href*=chevron-left]", "前のページ"
    assert_select ".pdf-viewer__bar button[data-action='pdf#next'][title=?] svg use[href*=chevron-right]", "次のページ"
    assert_select ".pdf-viewer__bar button[data-action='pdf#zoomOut'][title=?] svg use[href*=zoom-out]", "縮小"
    assert_select ".pdf-viewer__bar button[data-action='pdf#zoomIn'][title=?] svg use[href*=zoom-in]", "拡大"
    assert_select ".pdf-viewer__bar button[data-action='pdf#fit'][title] svg use[href*=maximize]"
    assert_select ".pdf-viewer__bar button[data-action='pdf#close'][title=?] svg use[href*='#x']", "閉じる"
    # 等倍(100%)は % 表示自体をクリック式ボタンに統合
    assert_select "button.pdf-viewer__pct[data-action='pdf#actualSize'][title]"
    # 綴じ方向はアイコンボタン（状態は title/aria-label と JS で表現）
    assert_select ".pdf-viewer__bar button[data-pdf-target='dir'][data-action='pdf#toggleDirection'] svg use[href*=book-open]"
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

  test "progress strip shows pending steps as action links (原本確認ステップは撤去)" do
    m = Material.create!(user: @user, url: "https://example.com/strip", title: "ストリップ資料")
    get material_url(m)
    # 書誌なし→追記リンク / 未引用→引用タグへのアンカー（原本確認は撤去）
    assert_select ".progress-strip a[href=?]", edit_material_path(m), text: /書誌を追記/
    assert_select ".progress-strip a[href=?]", "#usage", text: /引用タグを使う/
    assert_select ".progress-strip", text: /原本/, count: 0
  end

  test "progress strip shows completed steps as checks" do
    m = Material.create!(user: @user, url: "https://example.com/done", title: "完了資料",
                         source: "サンプル誌")
    article = Article.create!(title: "引用元記事", created_by: @user)
    article.revise!(body: "[[ref:#{m.slug}]]", author: @user)
    get material_url(m)
    assert_select ".progress-strip .strip-step--done", text: /書誌/
    assert_select ".progress-strip .strip-step--done", text: /引用 1件/
  end

  test "detail page badges the media kind and drops the confidence badge" do
    m = Material.new(user: @user, title: "種別資料")
    m.file.attach(io: StringIO.new("x"), filename: "s.mp3", content_type: "audio/mpeg")
    m.save!
    get material_url(m)
    assert_response :success
    assert_select ".page-meta .badge", text: "音声"             # 分類バッジ
    assert_select ".page-meta .badge", text: "未確認", count: 0  # confidence バッジは撤去
    assert_select ".page-meta .badge", text: "原本確認済", count: 0
  end

  test "detail elevates 文字起こし above 書誌, surfaces 出典元/初出, shows a タグ zone" do
    m = Material.create!(user: @user, url: "https://x.test/zone", title: "ゾーン資料",
                         source: "サンプル誌", author: "サンプル著者",
                         published_year: 1981, published_month: 3)
    get material_url(m)
    assert_response :success
    body = response.body
    assert_operator body.index("transcription-section"), :<, body.index("bibliography-section")
    assert_select "section.tags-section h2", text: /タグ/
    assert_select ".material-identity", text: /出典元/
    assert_select ".material-identity", text: /初出/
  end

  test "a material without a transcription shows a clear 作成 CTA in the transcription zone" do
    media = Material.new(user: @user, title: "未起こし音声")
    media.file.attach(io: StringIO.new("x"), filename: "c.mp3", content_type: "audio/mpeg")
    media.save!
    get material_url(media)
    assert_select ".transcription-section a[role=button][href=?]", new_material_transcription_path(media), text: /パート|作成/
  end

  test "material detail lists transcription parts with edit links and an add link" do
    m = Material.new(user: @user, title: "パート音声")
    m.file.attach(io: StringIO.new("x"), filename: "p.mp3", content_type: "audio/mpeg")
    m.save!
    t1 = m.transcriptions.create!(author: @user, body: "前半本文", position: 1, label: "前半", status: "done")
    t2 = m.transcriptions.create!(author: @user, body: "後半本文", position: 2, label: "後半", status: "drafting")
    get material_url(m)
    assert_select ".transcription-section .transcript-part", count: 2
    assert_select "a[href=?]", edit_material_transcription_path(m, t1)
    assert_select "a[href=?]", edit_material_transcription_path(m, t2)
    assert_select ".transcription-section a[href=?]", new_material_transcription_path(m), text: /パート/
    assert_select ".transcription-section", text: /1\s*\/\s*2/  # 完了 1/2
  end

  test "progress strip includes transcription state for every material, including links" do
    media = Material.new(user: @user, title: "音声S")
    media.file.attach(io: StringIO.new("x"), filename: "s.mp3", content_type: "audio/mpeg")
    media.save!
    get material_url(media)
    assert_select ".progress-strip a[href=?]", new_material_transcription_path(media), text: /文字起こし/

    link = Material.create!(user: @user, url: "https://example.com/nt", title: "リンクNT")
    get material_url(link)
    assert_select ".progress-strip a[href=?]", new_material_transcription_path(link), text: /文字起こし/
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

  test "create stores the extracted file date without posting a candidates comment" do
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
    # メタデータ候補コメントの自動投稿は廃止（カラムへの記録のみ）。
    assert_equal 0, m.comments.count

    get material_url(m)
    assert_select ".bibliography dt", text: "ファイル作成日"
    assert_select ".bibliography dd", text: /2020年3月16日/
  end

  test "create without extractable metadata adds neither date nor comment" do
    file = fixture_file_upload("example-photo.png", "image/png")
    stub_singleton(MaterialMetadataExtractor, :call, { file_created_at: nil, details: {} }) do
      perform_enqueued_jobs do
        post materials_url, params: { material: { file: file, title: "抽出なし" } }
      end
    end
    m = Material.find_by!(title: "抽出なし")
    assert_nil m.file_created_at
    assert_equal 0, m.comments.count
  end

  test "creating a material does not create a stub article" do
    assert_no_difference("Article.count") do
      post materials_url, params: link_params(title: "スタブなし資料")
    end
  end

  test "create autofills title from filename (sans extension) when blank" do
    file = fixture_file_upload("example-photo.png", "image/png")
    assert_difference("Material.count", 1) do
      post materials_url, params: { material: { file: file } }
    end
    assert_equal "example-photo", Material.order(:id).last.title
  end

  # URL メタデータ（サイトAPI/og:title）の取得は外部 I/O なので後処理ジョブへ委譲する。
  # 詳細な補完ロジックは material_post_process_job_test を参照。ここは委譲の配線だけ確認する。
  test "create defers url title autofill to the post-process job" do
    stub_singleton(VideoMetadata, :call, nil) do
      stub_singleton(OgTitleFetcher, :call, "後から取得した題名") do
        assert_enqueued_with(job: MaterialPostProcessJob) do
          post materials_url, params: { material: { url: "https://example.com/deferred" } }
        end
        # 保存直後は ensure_title の保険で url のまま（同期では外部取得しない）。
        assert_equal "https://example.com/deferred", Material.order(:id).last.title
        perform_enqueued_jobs
        assert_equal "後から取得した題名", Material.order(:id).last.reload.title
      end
    end
  end

  test "create keeps a given title (no autofill needed)" do
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
    article.revise!(body: "本文[[ref:#{m.slug}]]", author: @user)
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
    assert_operator body.index("Alpha"), :<, body.index("Bravo"), "Alpha should come before Bravo"
  end

  test "index sorts by created_at desc by default" do
    Material.create!(user: @user, url: "https://example.com/old", title: "OLDONE")
    Material.create!(user: @user, url: "https://example.com/new", title: "NEWONE")
    get materials_url
    body = @response.body
    assert_operator body.index("NEWONE"), :<, body.index("OLDONE"), "newest first by default"
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

  test "create persists rights but ignores confidence (form input retired)" do
    @user.update!(role: "admin")
    post materials_url, params: { material: {
      url: "https://x.test/c", confidence: "confirmed", rights: "quotable"
    } }
    m = Material.order(:created_at).last
    assert_equal "quotable", m.rights
    assert_equal "unconfirmed", m.confidence # confidence は permit から外したので無視される
  end

  test "update flashes a toast notice" do
    m = Material.create!(user: @user, url: "https://x.test/u", title: "更新前")
    patch material_url(m), params: { material: { title: "更新後" } }
    follow_redirect!
    assert_select ".toast-stack .flash--notice .flash__msg", text: "資料を保存しました。"
  end

  test "create persists ownership; any member can set it (no admin gate) and show badges it" do
    post materials_url, params: { material: { url: "https://x.test/own", title: "所持資料", ownership: "partial" } }
    m = Material.find_by!(title: "所持資料")
    assert_equal "partial", m.ownership   # 非adminでも設定できる
    get material_url(m)
    assert_select ".badge", text: /部分所有/
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

  test "confidence is not settable via the material form, even for admin (retired)" do
    @user.update!(role: "admin")
    m = Material.create!(user: @user, url: "https://x.test/a2", confidence: "unconfirmed")
    patch material_url(m), params: { material: { url: "https://x.test/a2", confidence: "confirmed" } }
    assert_equal "unconfirmed", m.reload.confidence
  end

  test "material form retires the confidence input and labels the date 初出" do
    get new_material_url
    assert_response :success
    assert_select "[name=?]", "material[confidence]", count: 0
    assert_select "label[for=?]", "material_published_year", text: "初出"
  end

  test "new form offers a 分類 select with 自動で判定 and grouped + top-level options, and lists Spotify in the URL hint" do
    get new_material_url
    assert_response :success
    assert_select "select[name=?] option", "material[kind]", text: "自動で判定"
    assert_select "select[name=?] option[value=video]", "material[kind]", text: "動画"          # 1段目で直接
    assert_select "select[name=?] optgroup[label=?] option[value=book]", "material[kind]", "出版物・文書", text: "書籍"
    assert_select ".field__hint", text: /Spotify/
  end

  test "kind persists from the form and the detail badge reflects it" do
    post materials_url, params: { material: { url: "https://example.com/podcast", kind: "audio", title: "ポッドキャスト" } }
    m = Material.find_by!(title: "ポッドキャスト")
    assert_equal "audio", m.kind
    get material_url(m)
    assert_select ".page-meta .badge", text: "音声"
  end

  test "an unclassified PDF detail badges 未分類; a YouTube link auto-badges 動画" do
    pdf = Material.new(user: @user, title: "未分類PDF")
    pdf.file.attach(io: StringIO.new("%PDF-1.4"), filename: "d.pdf", content_type: "application/pdf")
    pdf.save!
    get material_url(pdf)
    assert_select ".page-meta .badge", text: "未分類"

    yt = Material.create!(user: @user, url: "https://youtu.be/dQw4w9WgXcQ", title: "動画リンク")
    get material_url(yt)
    assert_select ".page-meta .badge", text: "動画"
  end

  test "tags stay visible outside the collapsible while bibliographic fields sit inside it" do
    get new_material_url
    assert_response :success
    assert_select "details.secondary-meta input[name=?]", "material[author]"             # 著者=折りたたみ内
    assert_select "details.secondary-meta input[name=?]", "material[tag_names]", count: 0 # タグは折りたたみ外
    assert_select "input[name=?]", "material[tag_names]"                                  # 中段に可視で存在
  end

  test "the 初出 time inputs are hidden by default behind a +時刻 toggle" do
    get new_material_url
    assert_response :success
    assert_select "[data-time-disclosure-target='times'][hidden] input[name=?]", "material[published_hour]"
    assert_select "button[data-action=?]", "time-disclosure#open"
  end

  test "media material shows a transcription section" do
    m = Material.new(user: @user, title: "音声")
    m.file.attach(io: StringIO.new("x"), filename: "a.mp3", content_type: "audio/mpeg")
    m.save!
    get material_url(m)
    assert_select "a[href=?]", new_material_transcription_path(m)
  end

  test "every material, including a link, has a transcription section" do
    link = Material.create!(user: @user, title: "外部", url: "https://example.com/x")
    get material_url(link)
    assert_select "a[href=?]", new_material_transcription_path(link)
  end

  test "transcription parts show assignment-state badge, assignee picker, and progress summary" do
    media = Material.new(user: @user, title: "担当UI音声")
    media.file.attach(io: StringIO.new("x"), filename: "ui.mp3", content_type: "audio/mpeg")
    media.save!
    other = User.create!(email_address: "ui2@example.com", name: "UI2", provider: "discord", uid: "ui2")
    media.transcriptions.create!(author: @user, body: "a", position: 1, status: "drafting", assignee: other)
    media.transcriptions.create!(author: @user, body: "b", position: 2, status: "drafting")

    get material_url(media)
    assert_response :success
    # 状態バッジ（未担当/担当中）
    assert_select ".transcript-part", text: /担当中/
    assert_select ".transcript-part", text: /未担当/
    # 進捗要約（担当中/未担当のカウント）
    assert_select ".transcription-summary", text: /担当中/
    assert_select ".transcription-summary", text: /未担当/
    # 担当ピッカー: メンバーへ assign する member ルートの button_to が出る
    assert_select "form[action=?]", assign_material_transcription_path(media, media.transcriptions.first)
  end

  test "creating a material never creates a stub article (auto-generation retired)" do
    assert_no_difference -> { Article.count } do
      post materials_url, params: { material: { title: "スタブ無し資料", url: "https://x.test/nostub" },
                                    create_stub_article: "1" }
    end
    assert_raises(NameError) { StubArticleForMaterial } # サービスは削除済み
  end

  test "published_at can be entered down to the minute" do
    post materials_url, params: { material: {
      title: "時刻あり資料", url: "https://x.test/time",
      published_year: "1982", published_month: "3", published_day: "1",
      published_hour: "14", published_minute: "30"
    } }
    m = Material.find_by!(title: "時刻あり資料")
    assert_equal "time", m.published_precision      # 時刻まで入れたら time 精度（FuzzyDate）
    assert_equal 14, m.published_at.hour
    assert_equal 30, m.published_at.min
  end
end
