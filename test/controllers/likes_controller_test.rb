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
end
