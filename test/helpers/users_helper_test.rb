require "test_helper"

class UsersHelperTest < ActionView::TestCase
  test "display_name uses name when present" do
    u = User.new(name: "花子", email_address: "h@example.com")
    assert_equal "花子", display_name(u)
  end

  test "display_name falls back to email when name blank" do
    u = User.new(name: "", email_address: "h@example.com")
    assert_equal "h@example.com", display_name(u)
  end

  test "avatar_tag renders an initial when no avatar attached" do
    u = User.create!(name: "Zoe", email_address: "z@example.com", password: "password123")
    html = avatar_tag(u)
    assert_includes html, "avatar-initial"
    assert_includes html, "Z"
  end

  test "avatar_tag uses avatar_url when present and no attachment" do
    u = User.create!(email_address: "au@example.com", name: "AU", provider: "discord", uid: "u1",
                     avatar_url: "https://cdn.discordapp.com/avatars/1/abc.png")
    assert_includes avatar_tag(u), "https://cdn.discordapp.com/avatars/1/abc.png"
  end
end
