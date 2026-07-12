require "test_helper"

class ActivityTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(email_address: "act@example.com", password: "password123", name: "Act")
  end

  test "valid with user and action" do
    a = Activity.new(user: @user, action: "article.created", subject_label: "X")
    assert_predicate a, :valid?, a.errors.full_messages.join(", ")
  end

  test "subject is optional and survives subject deletion" do
    article = Article.create!(title: "Subj", created_by: @user)
    a = Activity.create!(user: @user, action: "article.created", subject: article, subject_label: "Subj")
    article.destroy
    assert_nil a.reload.subject
    assert_equal "Subj", a.subject_label
  end

  test "record with explicit label and nil subject" do
    assert_difference("Activity.count", 1) do
      Activity.record(actor: @user, action: "tag.deleted", subject_label: "ruby")
    end
    a = Activity.order(:id).last
    assert_equal @user, a.user
    assert_equal "tag.deleted", a.action
    assert_nil a.subject
    assert_equal "ruby", a.subject_label
  end

  test "record derives label from subject title" do
    article = Article.create!(title: "導出", created_by: @user)
    Activity.record(actor: @user, action: "article.created", subject: article)
    assert_equal "導出", Activity.order(:id).last.subject_label
  end

  test "record derives label from subject title then name" do
    material = Material.create!(user: @user, url: "https://example.com/x", title: "資料X")
    Activity.record(actor: @user, action: "material.added", subject: material)
    assert_equal "資料X", Activity.order(:id).last.subject_label

    tag = Tag.create!(name: "lbl")
    Activity.record(actor: @user, action: "tag.created", subject: tag)
    assert_equal "lbl", Activity.order(:id).last.subject_label
  end

  test "transcription.assigned is an allowed action" do
    a = Activity.record(actor: @user, action: "transcription.assigned", subject_label: "音声X")
    assert_predicate a, :persisted?
    assert_equal "transcription.assigned", a.action
  end

  test "publication actions are part of the vocabulary" do
    assert_includes Activity::ACTIONS, "publication.registered"
    assert_includes Activity::ACTIONS, "publication.edited"
    assert_includes Activity::ACTIONS, "publication.deleted"
  end
end
