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
end
