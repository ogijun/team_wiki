require "test_helper"

class UploadTest < ActiveSupport::TestCase
  setup { @user = User.create!(email_address: "up@example.com", password: "password123", name: "UP") }

  test "valid png attachment" do
    upload = Upload.new(user: @user)
    upload.file.attach(io: StringIO.new("data"), filename: "a.png", content_type: "image/png")
    assert_predicate upload, :valid?
  end

  test "rejects disallowed content type" do
    upload = Upload.new(user: @user)
    upload.file.attach(io: StringIO.new("x"), filename: "a.exe", content_type: "application/octet-stream")
    assert_not upload.valid?
  end

  test "requires attachment" do
    assert_not Upload.new(user: @user).valid?
  end
end
