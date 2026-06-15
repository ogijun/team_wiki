require "test_helper"

class TranscriptionRevisionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(email_address: "trv@example.com", name: "TRV", provider: "discord", uid: "trv-user")
    sign_in_as(@user)
    @material = Material.new(user: @user, title: "音声")
    @material.file.attach(io: StringIO.new("x"), filename: "a.mp3", content_type: "audio/mpeg")
    @material.save!
    @part = @material.transcriptions.create!(author: @user, body: "初版", position: 1)
  end

  test "index lists the part's revisions" do
    @part.revisions.create!(author: @user, body: "v1")
    get material_transcription_revisions_url(@material, @part)
    assert_response :success
  end

  # 記事差分と同じく @diff を html_safe で出力するため、Diffy のエスケープを回帰テストで固定。
  test "diff escapes HTML in transcription revision bodies (no XSS through the html_safe diff)" do
    payload = "<script>alert('XSS-TDIFF')</script>"
    a = @part.revisions.create!(author: @user, body: "安全な行")
    b = @part.revisions.create!(author: @user, body: "安全な行\n#{payload}")
    get material_transcription_revision_url(@material, @part, b, a: a.id)
    assert_response :success
    assert_no_match %r{<script>alert\('XSS-TDIFF'\)}, @response.body
    assert_includes @response.body, "&lt;script&gt;"
    assert_includes @response.body, "XSS-TDIFF"
  end
end
