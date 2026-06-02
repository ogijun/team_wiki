require "test_helper"

class MaterialsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(email_address: "mc@example.com", password: "password123", name: "MC")
    login
  end

  def login
    post session_url, params: { email_address: @user.email_address, password: "password123" }
  end

  def link_params(extra = {})
    { material: { url: "https://youtu.be/dQw4w9WgXcQ", title: "動画", tag_names: "ruby, rails" }.merge(extra) }
  end

  test "index requires login" do
    delete session_url
    get materials_url
    assert_redirected_to new_session_url
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

  test "new prefills page_id from query" do
    page = Page.create!(title: "PP", created_by: @user)
    get new_material_url(page_id: page.id)
    assert_response :success
    assert_select "input[name=?][value=?]", "material[page_id]", page.id.to_s
  end

  test "destroy removes material" do
    m = Material.create!(user: @user, url: "https://example.com/a")
    assert_difference("Material.count", -1) do
      delete material_url(m)
    end
    assert_redirected_to materials_url
  end

  test "page show lists its materials and add link" do
    page = Page.create!(title: "Docs", created_by: @user)
    PageRevisionCreator.call(page: page, body: "本文", author: @user)
    Material.create!(user: @user, url: "https://example.com/d", title: "資料A", page: page)
    get page_url(page)
    assert_response :success
    assert_select "a", text: "資料A"
    assert_select "a[href=?]", new_material_path(page_id: page.id)
  end
end
