require "test_helper"
require "rake"

class CleanupAutoStubsTaskTest < ActiveSupport::TestCase
  setup do
    Rails.application.load_tasks if Rake::Task.tasks.empty?
    Rake::Task["articles:cleanup_untouched_auto_stubs"].reenable
    @user = User.create!(email_address: "rt@example.com", name: "RT", provider: "discord", uid: "rt")
    @stub = Article.create_with_revision!({ title: "掃除対象", status: "stub", created_by: @user },
                                          body: "案内\n\n[[ref:x]]\n", author: @user, edit_summary: "資料から自動作成")
    @kept = Article.create_with_revision!({ title: "残す", status: "stub", created_by: @user },
                                          body: "案内", author: @user, edit_summary: "資料から自動作成")
    @kept.revise!(body: "加筆", author: @user) # 手が加わった
  end

  test "DRY_RUN does not delete" do
    ENV["DRY_RUN"] = "1"
    assert_no_difference -> { Article.count } do
      Rake::Task["articles:cleanup_untouched_auto_stubs"].invoke
    end
  ensure
    ENV.delete("DRY_RUN")
    Rake::Task["articles:cleanup_untouched_auto_stubs"].reenable
  end

  test "deletes only untouched auto-stubs" do
    Rake::Task["articles:cleanup_untouched_auto_stubs"].invoke
    assert_not Article.exists?(@stub.id)
    assert Article.exists?(@kept.id)
  end
end
