require "test_helper"

class MaterialTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(email_address: "mat@example.com", password: "password123", name: "Mat")
  end

  def attach_png(material)
    material.file.attach(io: StringIO.new("x"), filename: "a.png", content_type: "image/png")
    material
  end

  test "blank rights is normalized to nil (フォームの未設定=空文字を許容)" do
    m = Material.new(user: @user, url: "https://example.com/x", title: "t", rights: "")
    assert m.valid?, m.errors.full_messages.join(", ")
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
    assert m.valid?, m.errors.full_messages.join(", ")
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
    assert Material.new(base.merge(isbn: "978-4-04-410103-3")).valid?
    assert Material.new(base.merge(isbn: "404410103X")).valid?
    bad = Material.new(base.merge(isbn: "ABC-DEF"))
    assert_not bad.valid?
    assert bad.errors[:isbn].any?
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
    assert m.valid?, m.errors.full_messages.join(", ")
  end

  test "link-type material is valid" do
    m = Material.new(user: @user, url: "https://youtu.be/abc123")
    assert m.valid?, m.errors.full_messages.join(", ")
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
    assert bad.errors[:published_precision].any?
  end

  test "thumbnailable_file? is true for image, false for non-image and links" do
    img = attach_png(Material.new(user: @user))
    assert img.thumbnailable_file?
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
    assert m.errors[:confidence].any?
  end

  test "rights allows nil and valid values, rejects others" do
    assert Material.new(user: @user, url: "https://x.test/a", rights: nil).valid?
    assert Material.new(user: @user, url: "https://x.test/a", rights: "quotable").valid?
    bad = Material.new(user: @user, url: "https://x.test/a", rights: "bogus")
    assert_not bad.valid?
    assert bad.errors[:rights].any?
  end

  test "labels map slug to Japanese; rights nil label is 未設定" do
    m = Material.new(user: @user, url: "https://x.test/a", confidence: "confirmed", rights: "private")
    assert_equal "原本確認済", m.confidence_label
    assert_equal "全文非公開", m.rights_label
    assert_equal "未設定", Material.new(user: @user, url: "https://x.test/a", rights: nil).rights_label
  end

  test "transcribable? is true for media kinds, false for plain links" do
    audio = Material.new(user: @user)
    audio.file.attach(io: StringIO.new("x"), filename: "a.mp3", content_type: "audio/mpeg")
    audio.save!
    assert audio.transcribable?

    link = Material.create!(user: @user, title: "外部記事", url: "https://example.com/article")
    assert_not link.transcribable?
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
    assert s[:total_bytes].positive?
  end

  test "library_summary total_bytes counts only material files, not avatars" do
    u = create(:user)
    u.avatar.attach(io: StringIO.new("avatardata"), filename: "a.png", content_type: "image/png")
    create(:material, :with_pdf)            # 唯一の資料ファイル（"%PDF-1.4"）
    assert_equal "%PDF-1.4".bytesize, Material.library_summary[:total_bytes]
  end
end
