require "test_helper"

class TranscriptionsControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    @user = User.create!(email_address: "tc@example.com", name: "TC", provider: "discord", uid: "tc-user")
    sign_in_as(@user)
    @media = Material.new(user: @user, title: "動画")
    @media.file.attach(io: StringIO.new("x"), filename: "v.mp4", content_type: "video/mp4")
    @media.save!
    @link = Material.create!(user: @user, title: "外部記事", url: "https://example.com/x")
  end

  def part(material = @media, **attrs)
    material.transcriptions.create!({ author: @user, body: "本文", position: material.transcriptions.size + 1 }.merge(attrs))
  end

  test "new renders a blank part form" do
    get new_material_transcription_url(@media)
    assert_response :success
    assert_select "form"
  end

  test "create adds a part, assigns next position, records activity, creates first revision" do
    assert_difference -> { @media.transcriptions.count } => 1, -> { TranscriptionRevision.count } => 1 do
      assert_difference "Activity.where(action: 'transcription.created').count", 1 do
        post material_transcriptions_url(@media),
             params: { transcription: { body: "起こし本文", status: "drafting", label: "前半" } }
      end
    end
    t = @media.transcriptions.order(:position).last
    assert_equal 1, t.position
    assert_equal "前半", t.label
    assert_redirected_to material_url(@media)
  end

  test "second create gets the next position" do
    part(position: 1)
    post material_transcriptions_url(@media), params: { transcription: { body: "2つ目", status: "drafting" } }
    assert_equal 2, @media.transcriptions.order(:position).last.position
  end

  test "create can assign an assignee" do
    worker = User.create!(email_address: "w2@example.com", name: "W2", provider: "discord", uid: "w2")
    post material_transcriptions_url(@media), params: { transcription: { body: "x", assignee_id: worker.id } }
    assert_equal worker, @media.transcriptions.last.assignee
  end

  test "show renders the part full body" do
    t = part(body: "全文ボディ")
    get material_transcription_url(@media, t)
    assert_response :success
    assert_select ".prewrap", text: "全文ボディ"
  end

  test "update edits a part and appends a revision only when body changes" do
    t = part(body: "v1")
    assert_difference "t.revisions.count", 1 do
      patch material_transcription_url(@media, t), params: { transcription: { body: "v2", status: "drafting", lock_version: t.lock_version } }
    end
    assert_equal "v2", t.reload.body
    assert_no_difference "t.revisions.count" do
      patch material_transcription_url(@media, t), params: { transcription: { body: "v2", status: "done", lock_version: t.reload.lock_version } }
    end
  end

  test "update with a stale lock_version is rejected with a conflict message" do
    t = part(body: "v1")
    stale = t.lock_version
    patch material_transcription_url(@media, t), params: { transcription: { body: "先に更新", lock_version: stale } } # 成功して version++
    patch material_transcription_url(@media, t), params: { transcription: { body: "後から", lock_version: stale } }   # 古い version
    assert_response :unprocessable_entity
    assert_select ".flash--alert", text: /更新/
    assert_equal "先に更新", t.reload.body
  end

  test "destroy removes the part" do
    t = part
    assert_difference -> { @media.transcriptions.count }, -1 do
      delete material_transcription_url(@media, t)
    end
    assert_redirected_to material_url(@media)
  end

  # 両方空で保存→削除確認は client(Stimulus)。サーバ側は「削除を許す配線」の有無だけ検証する。
  test "edit form enables blank-delete only when another part exists" do
    only = part
    get edit_material_transcription_url(@media, only)
    assert_select "form[data-transcription-form-can-delete-value=?]", "false" # 唯一のパート→削除しない

    second = part
    get edit_material_transcription_url(@media, second)
    assert_select "form[data-transcription-form-can-delete-value=?]", "true"  # 他にパートあり→削除可
  end

  test "new form does not enable blank-delete (nothing to delete yet)" do
    get new_material_transcription_url(@media)
    assert_select "form[data-transcription-form-can-delete-value=?]", "false"
  end

  test "emptying body on the only part is rejected (not saved), never silently blanked" do
    only = part(label: "唯一", body: "中身")
    patch material_transcription_url(@media, only),
          params: { transcription: { label: "", body: "", lock_version: only.lock_version } }
    assert_response :unprocessable_entity     # 本文必須でバリデーションエラー
    assert_equal "中身", only.reload.body     # 空保存されない
  end

  test "assign sets the assignee (to anyone) and records activity" do
    other = User.create!(email_address: "o@example.com", name: "O", provider: "discord", uid: "tc-other")
    t = part
    assert_difference -> { Activity.where(action: "transcription.assigned").count }, 1 do
      assert_difference "Notification.count", 1 do
        patch assign_material_transcription_url(@media, t), params: { assignee_id: other.id }
      end
    end
    assert_redirected_to @media
    assert_equal other, t.reload.assignee
    # 活動は「担当にされた人」が actor（タイムラインに本人として出る）
    assert_equal other, Activity.where(action: "transcription.assigned").last.user
    assert_equal other, Notification.last.recipient
    assert_equal "assignment", Notification.last.kind
  end

  test "assign with blank assignee_id clears the assignee (and does not log)" do
    other = User.create!(email_address: "o2@example.com", name: "O2", provider: "discord", uid: "tc-other2")
    t = part(assignee: other)
    assert_no_difference -> { Activity.where(action: "transcription.assigned").count } do
      patch assign_material_transcription_url(@media, t), params: { assignee_id: "" }
    end
    assert_nil t.reload.assignee
  end

  test "self-assigning notifies the material owner" do
    owner = create(:user)
    material = create(:material, user: owner)
    t = part(material)

    assert_difference "Notification.count", 1 do
      patch assign_material_transcription_url(material, t), params: { assignee_id: @user.id }
    end
    assert_equal owner, Notification.last.recipient
    assert_equal @user, t.reload.assignee
  end

  test "self-assigning the current user's material does not notify oneself" do
    t = part

    assert_no_difference "Notification.count" do
      patch assign_material_transcription_url(@media, t), params: { assignee_id: @user.id }
    end
  end

  test "assign requires login" do
    t = part
    delete session_url
    patch assign_material_transcription_url(@media, t), params: { assignee_id: @user.id }
    assert_redirected_to new_session_url
  end

  test "assign does not bump lock_version (independent of versioned body edits)" do
    t = part
    before = t.lock_version
    patch assign_material_transcription_url(@media, t), params: { assignee_id: @user.id }
    assert_equal before, t.reload.lock_version
  end

  test "assign responds with a turbo_stream replacing the part row" do
    t = part
    patch assign_material_transcription_url(@media, t),
          params: { assignee_id: @user.id }, as: :turbo_stream
    assert_response :success
    assert_match %r{turbo-stream action="replace" target="transcription_#{t.id}"}, response.body
  end

  test "unassigned part shows a self-assign button" do
    t = part

    get material_url(@media)

    assert_select "form[action=?] button", assign_material_transcription_path(@media, t), text: "やります！"
  end
end
