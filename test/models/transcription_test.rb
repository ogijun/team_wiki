require "test_helper"

class TranscriptionTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(email_address: "t@example.com", name: "T", provider: "discord", uid: "trans-user")
    @material = Material.new(user: @user, title: "音声資料")
    @material.file.attach(io: StringIO.new("x"), filename: "a.mp3", content_type: "audio/mpeg")
    @material.save!
  end

  test "authorization predicate: editable by any logged-in member (future: assignee+admin)" do
    t = @material.transcriptions.create!(author: @user, body: "x", position: 1)
    assert t.editable_by?(@user)
    assert_not t.editable_by?(nil)
  end

  test "valid with body, author, status" do
    t = Transcription.new(material: @material, author: @user, body: "書き起こし本文", status: "drafting")
    assert_predicate t, :valid?, t.errors.full_messages.join(", ")
  end

  test "requires body" do
    t = Transcription.new(material: @material, author: @user, body: "", status: "drafting")
    assert_not t.valid?
    assert_predicate t.errors[:body], :any?
  end

  test "rejects unknown status" do
    t = Transcription.new(material: @material, author: @user, body: "x", status: "bogus")
    assert_not t.valid?
  end

  test "status_label maps to japanese" do
    t = Transcription.new(status: "done")
    assert_equal "完了", t.status_label
  end

  test "accepts known creation methods and rejects unknown" do
    %w[manual ai ai_assisted].each do |m|
      t = Transcription.new(material: @material, author: @user, body: "x", status: "drafting", creation_method: m)
      assert_predicate t, :valid?, "#{m}: #{t.errors.full_messages.join(", ")}"
    end
    bad = Transcription.new(material: @material, author: @user, body: "x", status: "drafting", creation_method: "bogus")
    assert_not bad.valid?
    assert_predicate bad.errors[:creation_method], :any?
  end

  test "creation_method is optional and blank normalizes to nil" do
    t = Transcription.new(material: @material, author: @user, body: "x", status: "drafting", creation_method: "")
    assert_predicate t, :valid?, t.errors.full_messages.join(", ")
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

  test "contributors lists revision authors in first-contribution order" do
    bob = User.create!(email_address: "b@example.com", name: "B", provider: "discord", uid: "trans-bob")
    t = Transcription.create!(material: @material, author: @user, body: "v1", status: "drafting")
    t.revisions.create!(author: @user, body: "v1")
    t.revisions.create!(author: bob, body: "v2")
    t.revisions.create!(author: @user, body: "v3")
    assert_equal [ @user, bob ], t.contributors
  end

  test "preview helpers truncate long bodies by line count and report overflow lines" do
    short = Transcription.new(body: "1行目\n2行目\n3行目")
    assert_not short.long?
    assert_equal "1行目\n2行目\n3行目", short.preview_body
    assert_equal 0, short.overflow_lines

    long_body = (1..(Transcription::PREVIEW_LINES + 5)).map { |i| "行#{i}" }.join("\n")
    long = Transcription.new(body: long_body)
    assert_predicate long, :long?
    assert_equal Transcription::PREVIEW_LINES, long.preview_body.lines.size
    assert_equal 5, long.overflow_lines
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

  test "belongs to an optional assignee" do
    m = create(:material)
    assignee = create(:user)
    t = m.transcriptions.create!(author: @user, body: "x", position: 1, assignee: assignee)
    assert_equal assignee, t.assignee
    t2 = m.transcriptions.create!(author: @user, body: "y", position: 2)
    assert_nil t2.assignee
  end

  test "two parts can coexist on one material (uniqueness removed)" do
    m = create(:material)
    m.transcriptions.create!(author: @user, body: "1", position: 1)
    second = m.transcriptions.create!(author: @user, body: "2", position: 2)
    assert_predicate second, :persisted?
  end
end
