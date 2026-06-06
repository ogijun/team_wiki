require "test_helper"
require "view_component/test_case"

class CitationComponentTest < ViewComponent::TestCase
  setup do
    @user = User.create!(email_address: "c@example.com", password: "password123", name: "C")
  end

  test "full citation joins author, source, year, then linked title" do
    m = Material.create!(user: @user, title: "インタビュー", url: "https://x.test/a",
                         author: "サンプル著者", source: "サンプル誌",
                         published_at: Time.zone.local(1998), published_precision: "year")
    html = render_inline(CitationComponent.new(material: m)).to_html
    assert_includes html, "サンプル著者『サンプル誌』(1998). "
    assert_match(/<a [^>]*>インタビュー<\/a>/, html)
  end

  test "title-only citation has no lead separator" do
    m = Material.create!(user: @user, title: "メモ", url: "https://x.test/b")
    html = render_inline(CitationComponent.new(material: m)).to_html
    assert_no_match(/\. </, html)
    assert_match(/<a [^>]*>メモ<\/a>/, html)
  end
end
