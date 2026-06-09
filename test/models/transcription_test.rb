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

  test "accepts known creation methods and rejects unknown" do
    %w[manual ai ai_assisted].each do |m|
      t = Transcription.new(material: @material, author: @user, body: "x", status: "drafting", creation_method: m)
      assert t.valid?, "#{m}: #{t.errors.full_messages.join(", ")}"
    end
    bad = Transcription.new(material: @material, author: @user, body: "x", status: "drafting", creation_method: "bogus")
    assert_not bad.valid?
    assert bad.errors[:creation_method].any?
  end

  test "creation_method is optional and blank normalizes to nil" do
    t = Transcription.new(material: @material, author: @user, body: "x", status: "drafting", creation_method: "")
    assert t.valid?, t.errors.full_messages.join(", ")
    assert_nil t.creation_method
  end

  test "non-AI method clears ai service and model on save" do
    t = Transcription.create!(material: @material, author: @user, body: "x", status: "drafting",
                              creation_method: "manual", ai_service: "OpenAI", ai_model: "whisper")
    assert_nil t.ai_service
    assert_nil t.ai_model
  end

  test "AI method keeps ai service and model" do
    t = Transcription.create!(material: @material, author: @user, body: "x", status: "drafting",
                              creation_method: "ai", ai_service: "OpenAI", ai_model: "whisper-large-v3")
    assert_equal "OpenAI", t.ai_service
    assert_equal "whisper-large-v3", t.ai_model
  end

  test "creation_summary renders per method" do
    assert_nil Transcription.new.creation_summary
    assert_equal "手書き（聞き取り）", Transcription.new(creation_method: "manual").creation_summary
    assert_equal "AI", Transcription.new(creation_method: "ai").creation_summary
    assert_equal "AI（OpenAI / whisper-large-v3）",
                 Transcription.new(creation_method: "ai", ai_service: "OpenAI", ai_model: "whisper-large-v3").creation_summary
    assert_equal "AI下書き＋人手修正（OpenAI）",
                 Transcription.new(creation_method: "ai_assisted", ai_service: "OpenAI").creation_summary
  end
end
