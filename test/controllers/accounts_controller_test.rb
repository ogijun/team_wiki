require "test_helper"

class AccountsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(email_address: "me@example.com", name: "旧名", provider: "discord", uid: "acc-user")
    sign_in_as(@user)
  end

  test "edit requires login" do
    delete session_url
    get edit_account_url
    assert_redirected_to new_session_url
  end

  test "updates display name" do
    patch account_url, params: { user: { name: "新名", email_address: @user.email_address } }
    assert_equal "新名", @user.reload.name
  end

  test "updates email" do
    patch account_url, params: { user: { name: @user.name, email_address: "new@example.com" } }
    assert_equal "new@example.com", @user.reload.email_address
  end

  test "rejects email already taken" do
    User.create!(email_address: "taken@example.com", provider: "discord", uid: "acc-taken")
    patch account_url, params: { user: { name: @user.name, email_address: "taken@example.com" } }
    assert_response :unprocessable_entity
    assert_equal "me@example.com", @user.reload.email_address
  end
end
