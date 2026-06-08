require "test_helper"

class ActivityRecorderTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(email_address: "rec@example.com", password: "password123", name: "Rec")
  end

  test "records with explicit label and nil subject" do
    assert_difference("Activity.count", 1) do
      ActivityRecorder.record(actor: @user, action: "tag.deleted", subject_label: "ruby")
    end
    a = Activity.order(:id).last
    assert_equal @user, a.user
    assert_equal "tag.deleted", a.action
    assert_nil a.subject
    assert_equal "ruby", a.subject_label
  end

  test "derives label from subject title" do
    article = Article.create!(title: "導出", created_by: @user)
    ActivityRecorder.record(actor: @user, action: "article.created", subject: article)
    assert_equal "導出", Activity.order(:id).last.subject_label
  end

  test "derives label from display_title then name" do
    material = Material.create!(user: @user, url: "https://example.com/x", title: "資料X")
    ActivityRecorder.record(actor: @user, action: "material.added", subject: material)
    assert_equal "資料X", Activity.order(:id).last.subject_label

    tag = Tag.create!(name: "lbl")
    ActivityRecorder.record(actor: @user, action: "tag.created", subject: tag)
    assert_equal "lbl", Activity.order(:id).last.subject_label
  end
end
