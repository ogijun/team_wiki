require "test_helper"

class StubArticleForMaterialTest < ActiveSupport::TestCase
  setup { @user = User.create!(email_address: "stub@example.com", name: "S", provider: "discord", uid: "stub-user") }

  test "creates a stub article that cites the material" do
    m = Material.create!(user: @user, url: "https://example.com/x", title: "資料X")
    article = StubArticleForMaterial.call(material: m, author: @user)

    assert article.persisted?
    assert_equal "stub", article.status
    assert_equal "資料X", article.title
    assert_equal @user, article.created_by
    assert_includes article.current_revision.body, "[[ref:#{m.slug}]]"
    # 多対多が永続化され、資料側から逆引きできる
    assert_equal [ article.id ], m.reload.citing_articles.pluck(:id)
  end

  test "disambiguates the title when one already exists" do
    Article.create!(title: "資料Y", created_by: @user)
    m = Material.create!(user: @user, url: "https://example.com/y", title: "資料Y")

    article = StubArticleForMaterial.call(material: m, author: @user)
    assert_not_equal "資料Y", article.title
    assert article.title.start_with?("資料Y")
    assert article.persisted?
  end
end
