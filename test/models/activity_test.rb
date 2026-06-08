require "test_helper"

class ActivityTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(email_address: "act@example.com", password: "password123", name: "Act")
  end

  test "valid with user and action" do
    a = Activity.new(user: @user, action: "article.created", subject_label: "X")
    assert a.valid?, a.errors.full_messages.join(", ")
  end

  test "subject is optional and survives subject deletion" do
    article = Article.create!(title: "Subj", created_by: @user)
    a = Activity.create!(user: @user, action: "article.created", subject: article, subject_label: "Subj")
    article.destroy
    assert_nil a.reload.subject
    assert_equal "Subj", a.subject_label
  end
end
