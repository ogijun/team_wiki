require "test_helper"

class MaterialTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(email_address: "mat@example.com", password: "password123", name: "Mat")
  end

  def attach_png(material)
    material.file.attach(io: StringIO.new("x"), filename: "a.png", content_type: "image/png")
    material
  end

  test "file-type material is valid" do
    m = attach_png(Material.new(user: @user, title: "図"))
    assert m.valid?, m.errors.full_messages.join(", ")
  end

  test "belongs to an article optionally" do
    article = Article.create!(title: "P", created_by: @user)
    m = attach_png(Material.new(user: @user, article: article))
    assert m.save
    assert_equal article, m.reload.article
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

  test "display_title falls back to filename then url" do
    m = attach_png(Material.new(user: @user))
    assert_equal "a.png", m.display_title

    titled = attach_png(Material.new(user: @user, title: "正式名"))
    assert_equal "正式名", titled.display_title

    link = Material.new(user: @user, url: "https://example.com/doc")
    assert_equal "https://example.com/doc", link.display_title
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

  test "stores bibliographic fields and free-form memo" do
    m = Material.create!(user: @user, url: "https://x.test/a",
                         source: "サンプル誌", author: "サンプル著者",
                         memo: "後半のインタビューが要確認")
    m.reload
    assert_equal "サンプル誌", m.source
    assert_equal "サンプル著者", m.author
    assert_equal "後半のインタビューが要確認", m.memo
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
end
