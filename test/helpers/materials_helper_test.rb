require "test_helper"

class MaterialsHelperTest < ActionView::TestCase
  setup do
    @user = User.create!(email_address: "h@example.com", password: "password123", name: "H")
  end

  test "full citation joins author, source, year, then linked title" do
    m = Material.create!(user: @user, title: "インタビュー", url: "https://x.test/a",
                         author: "サンプル著者", source: "サンプル誌",
                         published_at: Time.zone.local(1998), published_precision: "year",
                         retrieved_on: Date.new(2026, 6, 5))
    html = citation_text(m)
    assert_match "サンプル著者『サンプル誌』(1998). ", html
    assert_match(/<a [^>]*>インタビュー<\/a>/, html)
    assert_match "［取得: 2026-06-05］", html
  end

  test "title-only citation has no lead and no separator" do
    m = Material.create!(user: @user, title: "メモ", url: "https://x.test/b")
    html = citation_text(m)
    assert_no_match(/\. </, html)
    assert_match(/<a [^>]*>メモ<\/a>/, html)
  end

  test "retrieved date is omitted for file materials" do
    m = Material.new(user: @user, title: "図", retrieved_on: Date.new(2026, 6, 5))
    m.file.attach(io: StringIO.new("x"), filename: "a.png", content_type: "image/png")
    m.save!
    html = citation_text(m)
    assert_no_match(/取得/, html)
  end

  def attach_png(m)
    m.file.attach(io: StringIO.new("x"), filename: "a.png", content_type: "image/png")
    m
  end

  test "material_thumb renders img for image file" do
    m = attach_png(Material.new(user: @user))
    m.save!
    assert_match(/<img /, material_thumb(m))
  end

  test "material_thumb renders youtube image for youtube link" do
    m = Material.create!(user: @user, url: "https://youtu.be/dQw4w9WgXcQ")
    html = material_thumb(m)
    assert_match(/<img /, html)
    assert_match "img.youtube.com/vi/dQw4w9WgXcQ", html
  end

  test "material_thumb renders link icon for non-youtube link" do
    m = Material.create!(user: @user, url: "https://example.com/page")
    assert_match "🔗", material_thumb(m)
    assert_no_match(/<img /, material_thumb(m))
  end

  test "material_thumb renders file icon for non-image file" do
    m = Material.new(user: @user)
    m.file.attach(io: StringIO.new("%PDF-1.4"), filename: "d.pdf", content_type: "application/pdf")
    m.save!
    assert_match "📄", material_thumb(m)
  end
end
