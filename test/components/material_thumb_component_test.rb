require "test_helper"
require "view_component/test_case"

class MaterialThumbComponentTest < ViewComponent::TestCase
  setup do
    @user = User.create!(email_address: "t@example.com", password: "password123", name: "T")
  end

  def attach(m, filename, content_type, body = "x")
    m.file.attach(io: StringIO.new(body), filename: filename, content_type: content_type)
    m
  end

  test "renders img for an image file" do
    m = attach(Material.new(user: @user), "a.png", "image/png")
    m.save!
    html = render_inline(MaterialThumbComponent.new(material: m)).to_html
    assert_match(/<img /, html)
  end

  test "renders youtube thumbnail image for a youtube link" do
    m = Material.create!(user: @user, url: "https://youtu.be/dQw4w9WgXcQ")
    html = render_inline(MaterialThumbComponent.new(material: m)).to_html
    assert_match(/<img /, html)
    assert_includes html, "img.youtube.com/vi/dQw4w9WgXcQ"
  end

  test "renders link icon for a non-youtube link" do
    m = Material.create!(user: @user, url: "https://example.com/page")
    html = render_inline(MaterialThumbComponent.new(material: m)).to_html
    assert_includes html, "🔗"
    assert_no_match(/<img /, html)
  end

  test "renders file icon for a non-image file" do
    m = attach(Material.new(user: @user), "d.pdf", "application/pdf", "%PDF-1.4")
    m.save!
    html = render_inline(MaterialThumbComponent.new(material: m)).to_html
    assert_includes html, "📄"
  end
end
