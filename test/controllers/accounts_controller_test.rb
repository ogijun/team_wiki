require "test_helper"

class AccountsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(email_address: "me@example.com", password: "password123", name: "旧名")
    post session_url, params: { email_address: @user.email_address, password: "password123" }
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
    User.create!(email_address: "taken@example.com", password: "password123")
    patch account_url, params: { user: { name: @user.name, email_address: "taken@example.com" } }
    assert_response :unprocessable_entity
    assert_equal "me@example.com", @user.reload.email_address
  end

  test "changes password with correct current password" do
    patch account_url, params: { user: {
      name: @user.name, email_address: @user.email_address,
      current_password: "password123", password: "newsecret1", password_confirmation: "newsecret1"
    } }
    assert @user.reload.authenticate("newsecret1")
  end

  test "rejects password change with wrong current password" do
    patch account_url, params: { user: {
      name: @user.name, email_address: @user.email_address,
      current_password: "wrong", password: "newsecret1", password_confirmation: "newsecret1"
    } }
    assert_response :unprocessable_entity
    assert @user.reload.authenticate("password123")
  end

  test "blank password leaves password unchanged and still updates name" do
    patch account_url, params: { user: {
      name: "名前だけ", email_address: @user.email_address,
      current_password: "", password: "", password_confirmation: ""
    } }
    assert_equal "名前だけ", @user.reload.name
    assert @user.authenticate("password123")
  end
end
