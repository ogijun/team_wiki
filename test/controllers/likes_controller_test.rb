require "test_helper"

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
    # 二重クリック競合で DB の一意制約に負けた経路を再現する。
    original_create = Like.method(:create!)
    Like.define_singleton_method(:create!) { |**| raise ActiveRecord::RecordNotUnique }
    begin
      post like_url, params: { reactable_type: "Article", reactable_id: @article.id }
    ensure
      Like.define_singleton_method(:create!, original_create)
    end
    assert_response :redirect
    assert_equal 0, @article.reload.likes_count
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
