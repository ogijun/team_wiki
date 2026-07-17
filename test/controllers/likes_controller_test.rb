require "test_helper"
require "minitest/mock"

class LikesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = create(:user)
    @article = create(:article)
    sign_in_as(@user)
  end

  test "create toggles a like and responds with turbo stream" do
    assert_difference("Like.count", 1) do
      post like_url, params: { reactable_type: "Article", reactable_id: @article.id }, as: :turbo_stream
    end
    assert_response :success
    assert_equal 1, @article.reload.likes_count

    assert_difference("Like.count", -1) do
      post like_url, params: { reactable_type: "Article", reactable_id: @article.id }, as: :turbo_stream
    end
    assert_equal 0, @article.reload.likes_count
  end

  test "invalid reactable type is rejected" do
    post like_url, params: { reactable_type: "User", reactable_id: @user.id }
    assert_response :bad_request
  end

  test "guests are redirected to login" do
    delete session_url
    post like_url, params: { reactable_type: "Article", reactable_id: @article.id }
    assert_redirected_to new_session_url
  end

  test "html fallback redirects back" do
    post like_url, params: { reactable_type: "Article", reactable_id: @article.id }
    assert_redirected_to root_url
  end

  test "concurrent duplicate like is idempotent instead of 500" do
    # 二重クリックの race: 両要求が「未Like」を見る状況を find_by の stub で再現する。
    Like.create!(reactor: @user, reactable: @article)
    Like.stub(:find_by, nil) do
      post like_url, params: { reactable_type: "Article", reactable_id: @article.id }
    end
    assert_response :redirect
    assert_equal 1, @article.reload.likes_count, "重複作成されず Like は1つのまま"
  end

  test "bulk-resolved liked flag suppresses per-row like queries" do
    material = Material.create!(user: @user, url: "https://example.com/likes-n1", title: "N+1検証")
    3.times { |i| material.comments.create!(body: "c#{i}", author: @user) }

    like_selects = 0
    counter = ->(*, payload) { like_selects += 1 if payload[:sql].match?(/SELECT.*FROM "likes"/) }
    ActiveSupport::Notifications.subscribed(counter, "sql.active_record") do
      get material_url(material)
    end
    # コメント3件でも Like の SELECT は一括解決の1回だけ（行ごとの exists? が走らないこと）
    assert_operator like_selects, :<=, 2, "likes への SELECT が行数に比例している（N+1 再発）"
  end
end
