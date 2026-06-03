require "test_helper"

class MaterialsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(email_address: "mc@example.com", name: "MC", provider: "discord", uid: "mat-user")
    login
  end

  def login
    sign_in_as(@user)
  end

  def link_params(extra = {})
    { material: { url: "https://youtu.be/dQw4w9WgXcQ", title: "動画", tag_names: "ruby, rails" }.merge(extra) }
  end

  test "index requires login" do
    delete session_url
    get materials_url
    assert_redirected_to new_session_url
  end

  test "index renders when logged in with a material" do
    Material.create!(user: @user, url: "https://example.com/a", title: "資料A")
    get materials_url
    assert_response :success
    assert_select "a", text: "資料A"
  end

  test "index json returns slug and title" do
    m = Material.create!(user: @user, url: "https://example.com/a", title: "資料A")
    get materials_url(format: :json)
    assert_response :success
    data = JSON.parse(@response.body)
    entry = data.find { |e| e["slug"] == m.slug }
    assert_equal "資料A", entry["title"]
  end

  test "create makes a link material with tags" do
    assert_difference("Material.count", 1) do
      post materials_url, params: link_params
    end
    m = Material.order(:id).last
    assert_equal "https://youtu.be/dQw4w9WgXcQ", m.url
    assert_equal %w[rails ruby], m.tags.pluck(:name).sort
    assert_redirected_to material_url(m)
  end

  test "create with neither file nor url re-renders" do
    assert_no_difference("Material.count") do
      post materials_url, params: { material: { title: "空" } }
    end
    assert_response :unprocessable_entity
  end

  test "new prefills article_id from query" do
    article = Article.create!(title: "PP", created_by: @user)
    get new_material_url(article_id: article.id)
    assert_response :success
    assert_select "input[name=?][value=?]", "material[article_id]", article.id.to_s
  end

  test "destroy removes material" do
    m = Material.create!(user: @user, url: "https://example.com/a")
    assert_difference("Material.count", -1) do
      delete material_url(m)
    end
    assert_redirected_to materials_url
  end

  test "create records material.added activity" do
    assert_difference("Activity.where(action: 'material.added').count", 1) do
      post materials_url, params: link_params
    end
  end

  test "destroy records material.deleted activity with label" do
    m = Material.create!(user: @user, url: "https://example.com/a", title: "資料Z")
    assert_difference("Activity.where(action: 'material.deleted').count", 1) do
      delete material_url(m)
    end
    assert_equal "資料Z", Activity.where(action: "material.deleted").order(:id).last.subject_label
  end

  test "article show lists its materials and add link" do
    article = Article.create!(title: "Docs", created_by: @user)
    ArticleRevisionCreator.call(article: article, body: "本文", author: @user)
    Material.create!(user: @user, url: "https://example.com/d", title: "資料A", article: article)
    get article_url(article)
    assert_response :success
    assert_select "a", text: "資料A"
    assert_select "a[href=?]", new_material_path(article_id: article.id)
  end
end
