require "test_helper"

class TranscriptionProgressControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(email_address: "tp@example.com", name: "TP", provider: "discord", uid: "tp-user")
    sign_in_as(@user)
  end

  test "index requires login" do
    delete session_url
    get transcriptions_url
    assert_redirected_to new_session_url
  end

  test "index groups materials by aggregated transcription status into tabs" do
    todo = Material.new(user: @user, title: "未着手動画")
    todo.file.attach(io: StringIO.new("x"), filename: "v.mp4", content_type: "video/mp4")
    todo.save!
    done = Material.new(user: @user, title: "完了音声")
    done.file.attach(io: StringIO.new("x"), filename: "a.mp3", content_type: "audio/mpeg")
    done.save!
    done.transcriptions.create!(author: @user, body: "ok", position: 1, status: "done")

    get transcriptions_url
    assert_response :success
    assert_select "[data-controller=tabs]"
    assert_select ".tabs .tab", count: 3
    assert_select "a", text: "完了音声"
    assert_select "a", text: "未着手動画"      # パート無し=未着手
  end

  test "recruiting filter only shows materials with an unassigned part" do
    recruiting = create(:material, user: @user, title: "募集中の資料")
    recruiting.transcriptions.create!(author: @user, body: "担当者待ち", position: 1)
    assigned = create(:material, user: @user, title: "担当済みの資料")
    assigned.transcriptions.create!(author: @user, assignee: create(:user), body: "担当あり", position: 1)

    get transcriptions_url(recruiting: 1)

    assert_select ".filters a[href=?]", transcriptions_path(recruiting: 1), text: "担当者募集中"
    assert_select "a", text: "募集中の資料"
    assert_select "a", text: "担当済みの資料", count: 0
  end
end
