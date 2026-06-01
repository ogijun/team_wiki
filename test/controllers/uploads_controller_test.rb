require "test_helper"

class UploadsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(email_address: "uc@example.com", password: "password123", name: "UC")
    post session_url, params: { email_address: @user.email_address, password: "password123" }
  end

  test "create returns json url for valid image" do
    file = Rack::Test::UploadedFile.new(StringIO.new("img"), "image/png", original_filename: "a.png")
    assert_difference("Upload.count", 1) do
      post uploads_url, params: { file: file }
    end
    assert_response :success
    assert JSON.parse(response.body)["url"].present?
  end

  test "create rejects invalid type" do
    file = Rack::Test::UploadedFile.new(StringIO.new("x"), "application/octet-stream", original_filename: "a.bin")
    assert_no_difference("Upload.count") do
      post uploads_url, params: { file: file }
    end
    assert_response :unprocessable_entity
  end
end
