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

  test "show renders the full transcription body" do
    Transcription.create!(material: @media, author: @user, body: "全" * 500, status: "done")
    get material_transcription_url(@media)
    assert_response :success
    assert_select ".prewrap", text: /全{500}/
    assert_select "a", text: "文字起こしを編集"
  end

  test "show redirects to the material when no transcription exists" do
    get material_transcription_url(@media)
    assert_redirected_to material_url(@media)
  end

  test "material page truncates a long transcription with an overflow link" do
    Transcription.create!(material: @media, author: @user,
                          body: "き" * (Transcription::PREVIEW_LIMIT + 123), status: "drafting")
    get material_url(@media)
    assert_select ".prewrap", text: /\Aき{#{Transcription::PREVIEW_LIMIT}}\z/
    assert_select "a[href=?]", material_transcription_path(@media), text: /続きを読む（あと123文字）/
  end

  test "material page shows a short transcription in full without the overflow link" do
    Transcription.create!(material: @media, author: @user, body: "短い全文", status: "done")
    get material_url(@media)
    assert_select ".prewrap", text: "短い全文"
    assert_select "a", text: /続きを読む/, count: 0
  end

  test "each body change appends a revision; status-only changes do not" do
    assert_difference "TranscriptionRevision.count", 1 do
      patch material_transcription_url(@media), params: { transcription: { body: "v1", status: "drafting" } }
    end
    assert_difference "TranscriptionRevision.count", 1 do
      patch material_transcription_url(@media), params: { transcription: { body: "v2", status: "drafting" } }
    end
    assert_no_difference "TranscriptionRevision.count" do
      patch material_transcription_url(@media), params: { transcription: { body: "v2", status: "done" } }
    end
    assert_equal %w[v1 v2], @media.reload.transcription.revisions.order(:created_at).pluck(:body)
  end

  test "show lists contributor avatars" do
    bob = User.create!(email_address: "tb@example.com", name: "TB", provider: "discord", uid: "tc-bob")
    t = Transcription.create!(material: @media, author: @user, body: "v1", status: "drafting")
    t.revisions.create!(author: @user, body: "v1")
    t.revisions.create!(author: bob, body: "v2")
    get material_transcription_url(@media)
    assert_select ".page-meta .contributors a[href=?]", user_path(@user)
    assert_select ".page-meta .contributors a[href=?]", user_path(bob)
    assert_select "a", text: "履歴"
  end

  test "revision history lists versions and shows a diff" do
    t = Transcription.create!(material: @media, author: @user, body: "一行目", status: "drafting")
    r1 = t.revisions.create!(author: @user, body: "一行目")
    r2 = t.revisions.create!(author: @user, body: "一行目\n二行目")

    get material_transcription_revisions_url(@media)
    assert_response :success
    assert_select "a", text: /前の版との差分/

    get material_transcription_revision_url(@media, r2, a: r1.id)
    assert_response :success
    assert_select ".diff ins", text: /二行目/
  end

  test "records a transcription.created activity on first save" do
    assert_difference "Activity.where(action: 'transcription.created').count", 1 do
      patch material_transcription_url(@media), params: { transcription: { body: "初回", status: "drafting" } }
    end
    act = Activity.where(action: "transcription.created").order(:id).last
    assert_equal @media, act.subject
    assert_equal @media.title, act.subject_label
  end

  test "records a transcription.edited activity on subsequent saves" do
    Transcription.create!(material: @media, author: @user, body: "v1", status: "drafting")
    assert_difference "Activity.where(action: 'transcription.edited').count", 1 do
      assert_no_difference "Activity.where(action: 'transcription.created').count" do
        patch material_transcription_url(@media), params: { transcription: { body: "v2", status: "done" } }
      end
    end
  end

  test "creates a transcription on update" do
    patch material_transcription_url(@media), params: { transcription: { body: "起こし本文", status: "drafting" } }
    assert_redirected_to material_url(@media)
    t = @media.reload.transcription
    assert_equal "起こし本文", t.body
    assert_equal @user, t.author
    assert_equal "drafting", t.status
  end

  test "records AI creation method with service and model" do
    patch material_transcription_url(@media), params: { transcription: {
      body: "AIで起こした", status: "drafting",
      creation_method: "ai", ai_service: "OpenAI", ai_model: "whisper-large-v3"
    } }
    assert_redirected_to material_url(@media)
    t = @media.reload.transcription
    assert_equal "ai", t.creation_method
    assert_equal "OpenAI", t.ai_service
    assert_equal "whisper-large-v3", t.ai_model
  end

  test "manual creation method clears AI service and model" do
    patch material_transcription_url(@media), params: { transcription: {
      body: "手書き", status: "drafting",
      creation_method: "manual", ai_service: "OpenAI", ai_model: "whisper"
    } }
    t = @media.reload.transcription
    assert_equal "manual", t.creation_method
    assert_nil t.ai_service
    assert_nil t.ai_model
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

  test "index shows the assignee for in-progress transcripts" do
    worker = User.create!(email_address: "w@example.com", name: "ワーカー", provider: "discord", uid: "worker")
    Transcription.create!(material: @media, author: worker, body: "途中まで", status: "drafting")
    get transcriptions_url
    assert_select ".meta", text: /ワーカー/
  end
end
