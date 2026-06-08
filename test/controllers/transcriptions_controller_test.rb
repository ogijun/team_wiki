require "test_helper"

class TranscriptionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(email_address: "tc@example.com", name: "TC", provider: "discord", uid: "tc-user")
    sign_in_as(@user)
    @media = Material.new(user: @user, title: "動画")
    @media.file.attach(io: StringIO.new("x"), filename: "v.mp4", content_type: "video/mp4")
    @media.save!
    @link = Material.create!(user: @user, title: "外部記事", url: "https://example.com/x")
  end

  test "creates a transcription on update" do
    patch material_transcription_url(@media), params: { transcription: { body: "起こし本文", status: "drafting" } }
    assert_redirected_to material_url(@media)
    t = @media.reload.transcription
    assert_equal "起こし本文", t.body
    assert_equal @user, t.author
    assert_equal "drafting", t.status
  end

  test "updates existing transcription and records last author" do
    Transcription.create!(material: @media, author: @user, body: "v1", status: "drafting")
    other = User.create!(email_address: "o@example.com", name: "O", provider: "discord", uid: "o-user")
    sign_in_as(other)
    patch material_transcription_url(@media), params: { transcription: { body: "v2", status: "done" } }
    t = @media.reload.transcription
    assert_equal "v2", t.body
    assert_equal "done", t.status
    assert_equal other, t.author
  end

  test "invalid (blank body) re-renders edit" do
    patch material_transcription_url(@media), params: { transcription: { body: "", status: "drafting" } }
    assert_response :unprocessable_entity
  end

  test "rejects transcription edit for non-media material" do
    get edit_material_transcription_url(@link)
    assert_redirected_to material_url(@link)
  end

  test "index groups media materials by transcription status" do
    todo = Material.new(user: @user, title: "未着手動画")
    todo.file.attach(io: StringIO.new("x"), filename: "v.mp4", content_type: "video/mp4")
    todo.save!
    done = Material.new(user: @user, title: "完了音声")
    done.file.attach(io: StringIO.new("x"), filename: "a.mp3", content_type: "audio/mpeg")
    done.save!
    Transcription.create!(material: done, author: @user, body: "ok", status: "done")
    Material.create!(user: @user, title: "リンク", url: "https://example.com/x") # 対象外

    get transcriptions_url
    assert_response :success
    assert_select "a", text: "未着手動画"
    assert_select "a", text: "完了音声"
    assert_select "a", text: "リンク", count: 0
  end
end
