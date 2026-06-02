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

  test "successful registration records user.joined activity" do
    assert_difference("Activity.where(action: 'user.joined').count", 1) do
      post registration_url, params: { user: {
        name: "新人", email_address: "join@example.com",
        password: "password123", password_confirmation: "password123"
      } }
    end
    a = Activity.where(action: "user.joined").order(:id).last
    joined = User.find_by(email_address: "join@example.com")
    assert_equal joined, a.user
    assert_equal joined, a.subject
  end
end
