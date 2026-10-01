require "test_helper"

class ChronicleControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(email_address: "ch@example.com", name: "CH", provider: "discord", uid: "chr-user")
    sign_in_as(@user)
  end

  test "index requires login" do
    delete session_url
    get chronicle_url
    assert_redirected_to new_session_url
  end

  test "index lists dated articles oldest first and excludes undated" do
    Article.create!(title: "無日付", created_by: @user)
    Article.create!(title: "1990年の出来事", created_by: @user,
                    starts: "1990")
    Article.create!(title: "1980年の出来事", created_by: @user,
                    starts: "1980")
    get chronicle_url
    assert_response :success
    assert_select "li", text: /1980年の出来事/
    assert_select "li", text: /1990年の出来事/
    assert_select "li", text: /無日付/, count: 0
    body = @response.body
    assert_operator body.index("1980年の出来事"), :<, body.index("1990年の出来事"), "oldest first"
  end

  test "index shows fuzzy label and range" do
    Article.create!(title: "戦争", created_by: @user, starts: "1939-09-01", ends: "1945-08")
    get chronicle_url
    assert_select "li", text: /1939年9月1日 〜 1945年8月/
  end

  test "lists dated materials and articles with type icons and links" do
    Article.create!(title: "年表記事", created_by: @user,
                    starts: "1981")
    material = Material.create!(user: @user, title: "年表資料", url: "https://x.test/c", published: "1979-04")
    get chronicle_url
    assert_response :success
    assert_select "a", text: /年表記事/
    assert_select ".chronicle-list a[href=?]", material_path(material), text: /年表資料/
    assert_select ".chronicle-list svg use[href*=landmark]"  # 資料アイコン
    assert_select ".chronicle-list svg use[href*=newspaper]" # 記事アイコン
  end

  test "shows publications with a buy link when purchasable" do
    Publication.create!(title: "年表に出る本", kind: "book", registered_by: @user,
                        released: "1995", store_url: "https://example.com/item")
    get chronicle_url
    assert_response :success
    assert_select "body", /年表に出る本/
    assert_select ".chronicle-list a[href='https://example.com/item'][target='_blank'][rel='noopener']"
  end

  test "shows an empty-state message when nothing is dated" do
    get chronicle_url
    assert_select ".muted", text: /日付のある記事・資料・発売物がまだありません/
  end
end
