require "test_helper"

class RegistrationsControllerTest < ActionDispatch::IntegrationTest
  test "creates a user and logs in" do
    assert_difference("User.count", 1) do
      post registration_url, params: { user: {
        name: "Alice", email_address: "alice@example.com",
        password: "password123", password_confirmation: "password123"
      } }
    end
    assert_redirected_to root_url
  end

  test "rejects mismatched password confirmation" do
    assert_no_difference("User.count") do
      post registration_url, params: { user: {
        name: "Bob", email_address: "bob@example.com",
        password: "password123", password_confirmation: "nope"
      } }
    end
    assert_response :unprocessable_entity
  end
end
