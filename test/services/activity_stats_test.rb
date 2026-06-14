require "test_helper"

class ActivityStatsTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(email_address: "as@example.com", name: "AS", provider: "discord", uid: "as-u")
  end

  test "daily_by_type buckets by JST day and folds per type (all data)" do
    Activity.create!(user: @user, action: "article.created", created_at: Time.zone.local(2026, 6, 14, 7, 30))
    Activity.create!(user: @user, action: "material.added",  created_at: Time.zone.local(2026, 6, 14, 9, 0))
    # JST 00:30（UTCでは前日15:30だが date(+9h) は 6/14 に入る）
    Activity.create!(user: @user, action: "comment.posted",  created_at: Time.zone.local(2026, 6, 14, 0, 30))

    d = ActivityStats.daily_by_type
    today = Date.new(2026, 6, 14)
    assert_equal 3, d[:total][today]
    assert_equal 1, d[:by_type]["article"][today]
    assert_equal 1, d[:by_type]["material"][today]
    assert_equal 0, d[:by_type]["tag"][today]   # 種類キーは常に揃う
  end

  test "first_date / range_start derive from the earliest activity (JST), Sunday-aligned" do
    created = Date.new(2026, 6, 10)
    Activity.create!(user: @user, action: "article.created", created_at: Time.zone.local(2026, 6, 10, 12, 0))
    assert_equal created, ActivityStats.first_date
    assert_equal created.beginning_of_week(:sunday), ActivityStats.range_start
  end

  test "first_date is nil and range_start falls back to this week with no activity" do
    travel_to Time.zone.local(2026, 6, 14, 12, 0) do
      assert_nil ActivityStats.first_date
      assert_equal Date.current.beginning_of_week(:sunday), ActivityStats.range_start
    end
  end

  test "hourly_by_type returns 24-length arrays bucketed by JST hour" do
    Activity.create!(user: @user, action: "article.created", created_at: Time.zone.local(2026, 6, 14, 7, 30))
    Activity.create!(user: @user, action: "article.edited",  created_at: Time.zone.local(2026, 6, 14, 7, 50))
    h = ActivityStats.hourly_by_type
    assert_equal 24, h[:total].length
    assert_equal 2, h[:total][7]
    assert_equal 2, h[:by_type]["article"][7]
    assert_equal 0, h[:total][8]
  end
end
