require "test_helper"
require "view_component/test_case"

class CitationComponentTest < ViewComponent::TestCase
  setup do
    @user = User.create!(email_address: "c@example.com", password: "password123", name: "C")
  end

  test "full citation joins author, source, year, then linked title and retrieved date" do
    m = Material.create!(user: @user, title: "インタビュー", url: "https://x.test/a",
                         author: "サンプル著者", source: "サンプル誌",
                         published_at: Time.zone.local(1998), published_precision: "year",
                         retrieved_on: Date.new(2026, 6, 5))
    html = render_inline(CitationComponent.new(material: m)).to_html
    assert_includes html, "サンプル著者『サンプル誌』(1998). "
    assert_match(/<a [^>]*>インタビュー<\/a>/, html)
    assert_includes html, "［取得: 2026-06-05］"
  end

  test "title-only citation has no lead separator" do
    m = Material.create!(user: @user, title: "メモ", url: "https://x.test/b")
    html = render_inline(CitationComponent.new(material: m)).to_html
    assert_no_match(/\. </, html)
    assert_match(/<a [^>]*>メモ<\/a>/, html)
  end

  test "retrieved date is omitted for file materials" do
    m = Material.new(user: @user, title: "図", retrieved_on: Date.new(2026, 6, 5))
    m.file.attach(io: StringIO.new("x"), filename: "a.png", content_type: "image/png")
    m.save!
    html = render_inline(CitationComponent.new(material: m)).to_html
    assert_no_match(/取得/, html)
  end
end
