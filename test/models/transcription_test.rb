require "test_helper"

class TranscriptionTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(email_address: "t@example.com", name: "T", provider: "discord", uid: "trans-user")
    @material = Material.new(user: @user, title: "音声資料")
    @material.file.attach(io: StringIO.new("x"), filename: "a.mp3", content_type: "audio/mpeg")
    @material.save!
  end

  test "valid with body, author, status" do
    t = Transcription.new(material: @material, author: @user, body: "書き起こし本文", status: "drafting")
    assert t.valid?, t.errors.full_messages.join(", ")
  end

  test "requires body" do
    t = Transcription.new(material: @material, author: @user, body: "", status: "drafting")
    assert_not t.valid?
    assert t.errors[:body].any?
  end

  test "rejects unknown status" do
    t = Transcription.new(material: @material, author: @user, body: "x", status: "bogus")
    assert_not t.valid?
  end

  test "one transcription per material" do
    Transcription.create!(material: @material, author: @user, body: "a", status: "drafting")
    dup = Transcription.new(material: @material, author: @user, body: "b", status: "drafting")
    assert_not dup.valid?
  end

  test "status_label maps to japanese" do
    t = Transcription.new(status: "done")
    assert_equal "完了", t.status_label
  end
end
