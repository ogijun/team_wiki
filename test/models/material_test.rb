require "test_helper"

class MaterialTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(email_address: "mat@example.com", password: "password123", name: "Mat")
  end

  test "ownership: blank normalizes to nil, inclusion validated, label maps" do
    m = Material.new(user: @user, url: "https://x.test/o", ownership: "")
    assert_predicate m, :valid?, m.errors.full_messages.join(", ")
    assert_nil m.ownership                          # 空文字→nil（未設定）
    m.ownership = "original"
    assert_predicate m, :valid?
    assert_equal "原本所有", m.ownership_label
    m.ownership = "bogus"
    assert_not_predicate m, :valid?                 # 不正値は弾く
  end

  test "ownership_label is nil when unset" do
    assert_nil Material.new(user: @user, url: "https://x.test/o2").ownership_label
  end

  test "authorization predicates: editable/deletable by any member" do
    m = Material.create!(user: @user, url: "https://x.test/authz", title: "認可")
    assert m.editable_by?(@user)
    assert m.deletable_by?(@user)
    assert_not m.editable_by?(nil)
    assert_not m.deletable_by?(nil)
  end

  def attach_png(material)
    material.file.attach(io: StringIO.new("x"), filename: "a.png", content_type: "image/png")
    material
  end

  # PDF::Reader が page_count=1 と読める最小の有効 PDF を組み立てる
  def one_page_pdf
    objects = [
      "1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n",
      "2 0 obj\n<< /Type /Pages /Kids [3 0 R] /Count 1 >>\nendobj\n",
      "3 0 obj\n<< /Type /Page /Parent 2 0 R /MediaBox [0 0 10 10] >>\nendobj\n"
    ]
    head = "%PDF-1.4\n"
    offsets = []
    pos = head.bytesize
    objects.each { |o| offsets << pos; pos += o.bytesize }
    xref = "xref\n0 4\n0000000000 65535 f \n" + offsets.map { |o| format("%010d 00000 n \n", o) }.join
    trailer = "trailer\n<< /Size 4 /Root 1 0 R >>\nstartxref\n#{pos}\n%%EOF"
    StringIO.new(head + objects.join + xref + trailer)
  end

  test "blank rights is normalized to nil (フォームの未設定=空文字を許容)" do
    m = Material.new(user: @user, url: "https://example.com/x", title: "t", rights: "")
    assert_predicate m, :valid?, m.errors.full_messages.join(", ")
    assert_nil m.rights
  end

  test "tag_names: clears all tags on '', preserves tags when not assigned (nil)" do
    m = Material.create!(user: @user, url: "https://x.test/a", title: "t", tag_names: "ruby, rails")
    assert_equal %w[rails ruby], m.tags.pluck(:name).sort

    Material.find(m.id).update!(title: "kept") # tag_names 未代入(nil) -> 既存タグ維持
    assert_equal %w[rails ruby], m.reload.tags.pluck(:name).sort

    m.update!(tag_names: "") # 明示的な空 -> 全クリア
    assert_empty m.reload.tags
  end

  test "file-type material is valid" do
    m = attach_png(Material.new(user: @user, title: "図"))
    assert_predicate m, :valid?, m.errors.full_messages.join(", ")
  end

  test "bibliographic detail fields store values and normalize blanks to nil" do
    m = Material.create!(user: @user, url: "https://x.test/bib", title: "書誌",
                         isbn: "4-04-410103-9", pages: "12-15, 52", publisher: "サンプル書店", volume: "1991年4月号")
    m.reload
    assert_equal "4-04-410103-9", m.isbn
    assert_equal "12-15, 52", m.pages
    assert_equal "サンプル書店", m.publisher
    assert_equal "1991年4月号", m.volume

    m.update!(isbn: "", pages: "", publisher: "", volume: "")
    assert_nil m.reload.isbn
    assert_nil m.pages
  end

  test "isbn accepts loose ISBN shapes and rejects letters" do
    base = { user: @user, url: "https://x.test/i", title: "i" }
    assert_predicate Material.new(base.merge(isbn: "978-4-04-410103-3")), :valid?
    assert_predicate Material.new(base.merge(isbn: "404410103X")), :valid?
    bad = Material.new(base.merge(isbn: "ABC-DEF"))
    assert_not bad.valid?
    assert_predicate bad.errors[:isbn], :any?
  end

  test "per-file upload limit is 1 gigabyte" do
    assert_equal 1.gigabyte, Material::MAX_BYTES
  end

  test "rejects a file larger than MAX_BYTES" do
    m = attach_png(Material.new(user: @user))
    # 実 1GB は載せられないので byte_size をスタブして境界だけ検証する
    m.file.blob.define_singleton_method(:byte_size) { Material::MAX_BYTES + 1 }
    assert_not m.valid?
    assert m.errors[:file].any? { |msg| msg.include?("大きすぎ") }
  end

  test "accepts a file at exactly MAX_BYTES" do
    m = attach_png(Material.new(user: @user))
    m.file.blob.define_singleton_method(:byte_size) { Material::MAX_BYTES }
    assert_predicate m, :valid?, m.errors.full_messages.join(", ")
  end

  test "link-type material is valid" do
    m = Material.new(user: @user, url: "https://youtu.be/abc123")
    assert_predicate m, :valid?, m.errors.full_messages.join(", ")
  end

  test "requires exactly one of file or url - neither is invalid" do
    m = Material.new(user: @user, title: "空")
    assert_not m.valid?
    assert_includes m.errors[:base], "ファイルかURLのどちらか一方を指定してください"
  end

  test "requires exactly one of file or url - both is invalid" do
    m = attach_png(Material.new(user: @user, url: "https://example.com/x"))
    assert_not m.valid?
    assert_includes m.errors[:base], "ファイルかURLのどちらか一方を指定してください"
  end

  test "rejects disallowed content type" do
    m = Material.new(user: @user)
    m.file.attach(io: StringIO.new("MZ"), filename: "evil.exe", content_type: "application/x-msdownload")
    assert_not m.valid?
    assert_includes m.errors[:file], "は対応していない形式です"
  end

  test "rejects url without http scheme" do
    m = Material.new(user: @user, url: "ftp://example.com/x")
    assert_not m.valid?
    assert_includes m.errors[:url], "は http(s) で始まる URL を指定してください"
  end

  test "title is auto-filled on create from filename (base) or url when blank" do
    img = attach_png(Material.new(user: @user))
    img.validate # before_validation :ensure_title
    assert_equal "a", img.title # "a.png" -> base "a"

    link = Material.new(user: @user, url: "https://example.com/doc")
    link.validate
    assert_equal "https://example.com/doc", link.title

    titled = attach_png(Material.new(user: @user, title: "正式名"))
    titled.validate
    assert_equal "正式名", titled.title # 入力済みは維持
  end

  test "can be tagged and tag exposes materials" do
    m = attach_png(Material.new(user: @user))
    m.save!
    tag = Tag.create!(name: "spec")
    m.tags << tag
    assert_includes tag.reload.materials, m
  end

  test "assigns a unique token slug on create" do
    a = attach_png(Material.new(user: @user))
    a.save!
    b = Material.create!(user: @user, url: "https://example.com/x")
    assert_match(/\A[a-z0-9]{8}\z/, a.slug)
    assert_not_equal a.slug, b.slug
  end

  test "stores bibliographic fields" do
    m = Material.create!(user: @user, url: "https://x.test/a",
                         source: "サンプル誌", author: "サンプル著者")
    m.reload
    assert_equal "サンプル誌", m.source
    assert_equal "サンプル著者", m.author
  end

  test "published wraps FuzzyDate when present, nil otherwise" do
    m = Material.new(user: @user, url: "https://x.test/a",
                     published_at: Time.zone.local(1998), published_precision: "year")
    assert_equal "1998年", m.published.label
    assert_nil Material.new(user: @user, url: "https://x.test/b").published
  end

  test "published_at and published_precision must be both present or both blank" do
    bad = Material.new(user: @user, url: "https://x.test/a", published_at: Time.zone.local(1998))
    assert_not bad.valid?
    assert_predicate bad.errors[:published_precision], :any?
  end

  test "thumbnailable_file? is true for image, false for non-image and links" do
    img = attach_png(Material.new(user: @user))
    assert_predicate img, :thumbnailable_file?
    link = Material.new(user: @user, url: "https://youtu.be/dQw4w9WgXcQ")
    assert_not link.thumbnailable_file?
  end

  test "thumbnail returns a representation for image, nil for link" do
    img = attach_png(Material.new(user: @user))
    img.save!
    assert_not_nil img.thumbnail(48)
    link = Material.create!(user: @user, url: "https://youtu.be/dQw4w9WgXcQ")
    assert_nil link.thumbnail(48)
  end

  test "preview_image_url is youtube thumbnail for youtube link, nil for file" do
    link = Material.create!(user: @user, url: "https://youtu.be/dQw4w9WgXcQ")
    assert_equal "https://img.youtube.com/vi/dQw4w9WgXcQ/hqdefault.jpg", link.preview_image_url
    img = attach_png(Material.new(user: @user))
    img.save!
    assert_nil img.preview_image_url
  end

  test "default confidence is unconfirmed" do
    m = Material.create!(user: @user, url: "https://x.test/a")
    assert_equal "unconfirmed", m.confidence
  end

  test "confidence must be one of CONFIDENCE_LEVELS" do
    m = Material.new(user: @user, url: "https://x.test/a", confidence: "bogus")
    assert_not m.valid?
    assert_predicate m.errors[:confidence], :any?
  end

  test "rights allows nil and valid values, rejects others" do
    assert_predicate Material.new(user: @user, url: "https://x.test/a", rights: nil), :valid?
    assert_predicate Material.new(user: @user, url: "https://x.test/a", rights: "quotable"), :valid?
    bad = Material.new(user: @user, url: "https://x.test/a", rights: "bogus")
    assert_not bad.valid?
    assert_predicate bad.errors[:rights], :any?
  end

  test "labels map slug to Japanese; rights nil label is 未設定" do
    m = Material.new(user: @user, url: "https://x.test/a", rights: "private")
    assert_equal "全文非公開", m.rights_label
    assert_equal "未設定", Material.new(user: @user, url: "https://x.test/a", rights: nil).rights_label
  end

  test "linearize_file! replaces the blob with a linearized PDF and is idempotent" do
    m = Material.new(user: @user, title: "PDF")
    m.file.attach(io: one_page_pdf, filename: "doc.pdf", content_type: "application/pdf")
    m.save!
    before = m.file.blob.id

    m.linearize_file!
    after = m.reload.file.blob.id
    assert_not_equal before, after, "blob が差し替わる"
    m.file.open { |f| assert PdfLinearizer.linearized?(f.path), "linearized になる" }

    stable = m.file.blob.id
    m.linearize_file!                       # 2回目は既にlinearizedなので no-op
    assert_equal stable, m.reload.file.blob.id, "冪等（再linearizeしない）"
  end

  test "linearize_file! is a no-op for non-pdf files" do
    m = attach_png(Material.new(user: @user))
    m.save!
    before = m.file.blob.id
    m.linearize_file!
    assert_equal before, m.reload.file.blob.id
  end

  test "bibliography_present? includes page_count" do
    assert_predicate Material.new(user: @user, url: "https://x.test/pc", page_count: 100), :bibliography_present?
  end

  test "library_summary does not double-count an image that has a page_count" do
    img = create(:material, :with_image)
    img.update_column(:page_count, 1)   # 画像に明示的に page_count が入っても二重に数えない
    assert_equal 1, Material.library_summary[:total_pages]
  end

  test "kind_for maps content types to media kinds" do
    assert_equal :image, Material.kind_for("image/png")
    assert_equal :video, Material.kind_for("video/mp4")
    assert_equal :audio, Material.kind_for("audio/mpeg")
    assert_equal :document, Material.kind_for("application/pdf")
    assert_equal :document, Material.kind_for("text/csv")
  end

  test "library_summary aggregates size, kind counts, and total pages" do
    create(:material)                       # リンク（既定）
    create(:material, :with_image)          # 画像
    pdf = create(:material, :with_pdf)      # 文書(PDF)
    pdf.update_column(:page_count, 12)
    create(:material, :with_audio)          # 音声

    s = Material.library_summary
    assert_equal 3, s[:file_count]          # 画像+PDF+音声（リンクはファイル無し）
    assert_equal({ link: 1, image: 1, document: 1, audio: 1 }, s[:kind_counts])
    assert_equal 13, s[:total_pages]        # PDF 12 + 画像 1
    assert_predicate s[:total_bytes], :positive?
  end

  test "library_summary total_bytes counts only material files, not avatars" do
    u = create(:user)
    u.avatar.attach(io: StringIO.new("avatardata"), filename: "a.png", content_type: "image/png")
    create(:material, :with_pdf)            # 唯一の資料ファイル（"%PDF-1.4"）
    assert_equal "%PDF-1.4".bytesize, Material.library_summary[:total_bytes]
  end

  test "backfill_page_counts! fills page_count for PDFs missing it and is idempotent" do
    m = Material.new(user: @user, title: "PDF")
    m.file.attach(io: one_page_pdf, filename: "doc.pdf", content_type: "application/pdf")
    m.save!
    assert_nil m.page_count

    assert_equal 1, Material.backfill_page_counts!   # 1件埋まる
    assert_equal 1, m.reload.page_count
    assert_equal 0, Material.backfill_page_counts!   # 2回目は対象なし（冪等）
  end

  test "has_many transcriptions ordered by position" do
    m = create(:material)
    b = m.transcriptions.create!(author: @user, body: "B", position: 2)
    a = m.transcriptions.create!(author: @user, body: "A", position: 1)
    assert_equal [ a, b ], m.transcriptions.to_a
  end

  test "transcription_status aggregates parts (todo/drafting/done)" do
    m = create(:material)
    assert_equal "todo", m.transcription_status
    m.transcriptions.create!(author: @user, body: "x", position: 1, status: "drafting")
    assert_equal "drafting", m.reload.transcription_status
    m.transcriptions.update_all(status: "done")
    assert_equal "done", m.reload.transcription_status
  end

  test "transcription_progress returns done/total counts" do
    m = create(:material)
    m.transcriptions.create!(author: @user, body: "x", position: 1, status: "done")
    m.transcriptions.create!(author: @user, body: "y", position: 2, status: "drafting")
    assert_equal [ 1, 2 ], m.reload.transcription_progress
  end

  test "destroying a material destroys its transcription parts" do
    m = create(:material)
    m.transcriptions.create!(author: @user, body: "x", position: 1)
    assert_difference "Transcription.count", -1 do
      m.destroy
    end
  end

  test "transcription_counts breaks parts into done / in_progress / unassigned" do
    u = User.create!(email_address: "c@example.com", name: "C", provider: "discord", uid: "cnt")
    m = Material.new(user: u, title: "数えるカウント")
    m.file.attach(io: StringIO.new("x"), filename: "c.mp3", content_type: "audio/mpeg")
    m.save!
    m.transcriptions.create!(author: u, body: "a", position: 1, status: "done")
    m.transcriptions.create!(author: u, body: "b", position: 2, status: "drafting", assignee: u)
    m.transcriptions.create!(author: u, body: "c", position: 3, status: "drafting")

    counts = m.transcription_counts
    assert_equal 3, counts[:total]
    assert_equal 1, counts[:done]
    assert_equal 1, counts[:in_progress]
    assert_equal 1, counts[:unassigned]
  end

  test "transcription_incomplete returns materials whose transcription is not done (todo or drafting)" do
    u = User.create!(email_address: "inc@example.com", name: "Inc", provider: "discord", uid: "inc")
    todo = Material.new(user: u, title: "未着手音声")
    todo.file.attach(io: StringIO.new("x"), filename: "t.mp3", content_type: "audio/mpeg"); todo.save!
    drafting = Material.new(user: u, title: "途中音声")
    drafting.file.attach(io: StringIO.new("x"), filename: "d.mp3", content_type: "audio/mpeg"); drafting.save!
    drafting.transcriptions.create!(author: u, body: "a", position: 1, status: "drafting")
    done = Material.new(user: u, title: "完了音声")
    done.file.attach(io: StringIO.new("x"), filename: "o.mp3", content_type: "audio/mpeg"); done.save!
    done.transcriptions.create!(author: u, body: "b", position: 1, status: "done")

    ids = Material.transcription_incomplete.pluck(:id)
    assert_includes ids, todo.id
    assert_includes ids, drafting.id
    assert_not_includes ids, done.id
  end
end
