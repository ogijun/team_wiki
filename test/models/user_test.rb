require "test_helper"

class UserTest < ActiveSupport::TestCase
  def build_user(**attrs)
    User.new({ email_address: "u#{rand(100000)}@example.com", password: "password123" }.merge(attrs))
  end

  test "downcases and strips email_address" do
    user = User.new(email_address: " DOWNCASED@EXAMPLE.COM ")
    assert_equal("downcased@example.com", user.email_address)
  end

  test "requires email and enforces uniqueness" do
    build_user(email_address: "dup@example.com").save!
    dup = build_user(email_address: "dup@example.com")
    assert_not dup.valid?
    assert dup.errors[:email_address].any?
  end

  test "accepts an image avatar" do
    u = build_user
    u.avatar.attach(io: StringIO.new("x"), filename: "a.png", content_type: "image/png")
    assert u.valid?, u.errors.full_messages.join(", ")
  end

  test "rejects non-image avatar" do
    u = build_user
    u.avatar.attach(io: StringIO.new("x"), filename: "a.pdf", content_type: "application/pdf")
    assert_not u.valid?
    assert u.errors[:avatar].any?
  end

  test "authenticate verifies password" do
    u = build_user(password: "secret123")
    u.save!
    assert u.authenticate("secret123")
    assert_not u.authenticate("wrong")
  end

  test "can be created without a password (oauth user)" do
    u = User.new(email_address: "oauth@example.com", provider: "discord", uid: "123")
    assert u.valid?, u.errors.full_messages.join(", ")
  end
end
