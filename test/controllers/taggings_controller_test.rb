require "test_helper"

class TaggingsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(email_address: "tg@example.com", name: "TG", provider: "discord", uid: "tagg-u")
    sign_in_as(@user)
    @tag = Tag.create!(name: "提案タグ")
  end

  test "material show surfaces matching tag suggestions with one-click add" do
    m = Material.create!(user: @user, url: "https://example.com/s", title: "提案タグを含む資料")
    get material_url(m)
    assert_select ".tag-suggestions", text: /#提案タグ/

    assert_difference "m.tags.count", 1 do
      post material_taggings_url(m, tag_slug: @tag.slug)
    end
    assert_redirected_to material_url(m)
    assert_includes m.reload.tags, @tag

    # 付与後は候補から消える
    get material_url(m)
    assert_select ".tag-suggestions", count: 0
  end

  test "article show surfaces suggestions and adds via slug route" do
    article = Article.create!(title: "提案タグの記事", created_by: @user)
    get article_url(article)
    assert_select ".tag-suggestions", text: /#提案タグ/

    assert_difference "article.tags.count", 1 do
      post article_taggings_url(article, tag_slug: @tag.slug)
    end
    assert_includes article.reload.tags, @tag
  end

  test "adding keeps existing tags and unknown slug 404s" do
    m = Material.create!(user: @user, url: "https://example.com/k", title: "提案タグ資料")
    m.tag_names = "既存"
    m.save!
    post material_taggings_url(m, tag_slug: @tag.slug)
    assert_equal %w[既存 提案タグ].sort, m.reload.tags.pluck(:name).sort

    post material_taggings_url(m, tag_slug: "nope")
    assert_response :not_found
  end
end
