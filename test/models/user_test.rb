require "test_helper"

class UserStreakTest < ActiveSupport::TestCase
  setup { @user = User.create!(email_address: "st@example.com", name: "St", provider: "discord", uid: "streak-u") }

  def act_on(date)
    Activity.create!(user: @user, action: "user.joined", created_at: date.in_time_zone.change(hour: 12))
  end

  test "counts consecutive days ending today, plus longest streak and total active days" do
    act_on(Date.current - 6) # 過去の孤立した1日
    act_on(Date.current - 2)
    act_on(Date.current - 1)
    act_on(Date.current)
    stats = @user.activity_stats
    assert_equal 3, stats[:current_streak]
    assert_equal 3, stats[:longest_streak]
    assert_equal 4, stats[:active_days]
  end

  test "a streak ending yesterday is still alive" do
    act_on(Date.current - 1)
    assert_equal 1, @user.activity_stats[:current_streak]
  end

  test "gaps break the current streak but longest remembers the past" do
    assert_equal({ current_streak: 0, longest_streak: 0, active_days: 0 }, @user.activity_stats)
    act_on(Date.current - 5)
    act_on(Date.current - 4)
    act_on(Date.current - 3)
    act_on(Date.current)
    stats = @user.activity_stats
    assert_equal 1, stats[:current_streak]
    assert_equal 3, stats[:longest_streak]
    assert_equal 4, stats[:active_days]
  end
end

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

  test "default role is editor" do
    u = User.create!(email_address: "r1@example.com")
    assert_equal "editor", u.role
    assert_not u.admin?
  end

  test "admin? true only for admin role" do
    u = User.create!(email_address: "r2@example.com", role: "admin")
    assert u.admin?
  end

  test "role must be editor or admin" do
    u = User.new(email_address: "r3@example.com", role: "bogus")
    assert_not u.valid?
    assert u.errors[:role].any?
  end
end
