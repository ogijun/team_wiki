require "test_helper"

class ArticlesHelperTest < ActionView::TestCase
  include ApplicationHelper # article_meta が icon() に依存（実ビューでは全ヘルパーが mix される）

  test "article_meta joins status, kind, date and comment count" do
    user = User.create!(email_address: "am@example.com", name: "AM", provider: "discord", uid: "am")
    a = Article.create!(title: "メタ記事", created_by: user, kind: "work", status: "stub")
    assert_equal "スタブ・作品 / #{a.updated_at.to_date.to_fs(:jp)}", article_meta(a)

    a.comments.create!(body: "x", author: user)
    html = article_meta(a)
    assert_includes html, "#message-circle"
    assert_includes html, "・"
  end

  test "article_meta omits kind when unset" do
    user = User.create!(email_address: "am2@example.com", name: "AM2", provider: "discord", uid: "am2")
    a = Article.create!(title: "種別なし", created_by: user, status: "writing")
    assert_equal "執筆中 / #{a.updated_at.to_date.to_fs(:jp)}", article_meta(a)
  end
end
