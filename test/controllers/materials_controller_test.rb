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

  test "index paginates with per param" do
    30.times { |i| Material.create!(user: @user, url: "https://example.com/#{i}", title: "M#{i}") }
    get materials_url(per: 25)
    assert_response :success
    assert_select "table.materials-table tbody tr", count: 25
    get materials_url(per: 50)
    assert_select "table.materials-table tbody tr", minimum: 26
  end

  test "index sorts by name ascending" do
    Material.create!(user: @user, url: "https://example.com/b", title: "Bravo")
    Material.create!(user: @user, url: "https://example.com/a", title: "Alpha")
    get materials_url(sort: "name", dir: "asc")
    assert_response :success
    body = @response.body
    assert body.index("Alpha") < body.index("Bravo"), "Alpha should come before Bravo"
  end

  test "index sorts by created_at desc by default" do
    Material.create!(user: @user, url: "https://example.com/old", title: "OLDONE")
    Material.create!(user: @user, url: "https://example.com/new", title: "NEWONE")
    get materials_url
    body = @response.body
    assert body.index("NEWONE") < body.index("OLDONE"), "newest first by default"
  end

  test "index ignores invalid sort and per" do
    Material.create!(user: @user, url: "https://example.com/x", title: "X")
    get materials_url(sort: "title); DROP TABLE", dir: "sideways", per: "9999")
    assert_response :success
  end

  test "index json stays unpaginated full list" do
    30.times { |i| Material.create!(user: @user, url: "https://example.com/j#{i}", title: "J#{i}") }
    get materials_url(format: :json, per: 25)
    data = JSON.parse(@response.body)
    assert_operator data.size, :>=, 30
  end

  test "index json includes thumb_url for youtube and null for plain link" do
    yt = Material.create!(user: @user, url: "https://youtu.be/dQw4w9WgXcQ", title: "動画")
    plain = Material.create!(user: @user, url: "https://example.com/page", title: "ページ")
    get materials_url(format: :json)
    data = JSON.parse(@response.body)
    yt_entry = data.find { |e| e["slug"] == yt.slug }
    plain_entry = data.find { |e| e["slug"] == plain.slug }
    assert_match "img.youtube.com/vi/dQw4w9WgXcQ", yt_entry["thumb_url"]
    assert_nil plain_entry["thumb_url"]
  end

  test "create persists bibliographic fields and year-only published date" do
    post materials_url, params: { material: {
      url: "https://x.test/a", source: "サンプル誌", author: "サンプル著者",
      retrieved_on: "2026-06-05", published_year: "1998", published_month: "", published_day: ""
    } }
    m = Material.order(:created_at).last
    assert_equal "サンプル誌", m.source
    assert_equal "サンプル著者", m.author
    assert_equal Date.new(2026, 6, 5), m.retrieved_on
    assert_equal "year", m.published_precision
    assert_equal 1998, m.published_at.year
  end

  test "create persists confidence and rights" do
    post materials_url, params: { material: {
      url: "https://x.test/c", confidence: "confirmed", rights: "quotable"
    } }
    m = Material.order(:created_at).last
    assert_equal "confirmed", m.confidence
    assert_equal "quotable", m.rights
  end
end
