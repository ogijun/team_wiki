require "test_helper"

class PublicationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(email_address: "pc@example.com", name: "PC", provider: "discord", uid: "pub-ctrl")
    sign_in_as(@user)
  end

  def create_publication(**attrs)
    Publication.create!({ title: "サンプル 文庫版", kind: "book", registered_by: @user }.merge(attrs))
  end

  test "index lists publications" do
    create_publication(title: "一覧に出る本")
    get publications_url
    assert_response :success
    assert_select "body", /一覧に出る本/
  end

  test "create sets registered_by to the current user and records an activity" do
    assert_difference [ "Publication.count", "Activity.count" ], 1 do
      post publications_url, params: { publication: {
        title: "新しい本", kind: "book", sales_status: "on_sale",
        store_url: "https://example.com/item", released_year: "1995", released_month: "3"
      } }
    end
    pub = Publication.last
    assert_equal @user, pub.registered_by
    assert_equal "month", pub.released_precision
    assert_redirected_to pub
    assert_equal "publication.registered", Activity.last.action
  end

  test "create with invalid input re-renders the form" do
    assert_no_difference "Publication.count" do
      post publications_url, params: { publication: { title: "", kind: "book" } }
    end
    assert_response :unprocessable_entity
  end

  test "create can link an article" do
    article = Article.create!(title: "作品記事", created_by: @user, kind: "work")
    post publications_url, params: { publication: { title: "紐付く本", kind: "book", article_id: article.id } }
    assert_equal article, Publication.last.article
  end

  test "update edits and records an activity" do
    pub = create_publication
    assert_difference "Activity.count", 1 do
      patch publication_url(pub), params: { publication: { title: "改題", kind: "video", sales_status: "out_of_print" } }
    end
    assert_redirected_to pub
    assert_equal "改題", pub.reload.title
    assert_equal "video", pub.kind
    assert_equal "publication.edited", Activity.last.action
  end

  test "destroy removes it and keeps the label in the activity feed" do
    pub = create_publication(title: "消える本")
    assert_difference "Publication.count", -1 do
      delete publication_url(pub)
    end
    assert_redirected_to publications_url
    assert_equal "publication.deleted", Activity.last.action
    assert_equal "消える本", Activity.last.subject_label
  end

  test "guests are redirected to sign in" do
    pub = create_publication
    # 他のコントローラテストと同じ作法でログアウトする（sign_out ヘルパは無い）。
    delete session_url
    get publications_url
    assert_redirected_to new_session_url
    delete publication_url(pub)
    assert_redirected_to new_session_url
  end
end
