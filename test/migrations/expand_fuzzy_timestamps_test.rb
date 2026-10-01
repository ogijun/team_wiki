require "test_helper"
require Rails.root.join("db/migrate/20261001000000_expand_fuzzy_timestamps")

class ExpandFuzzyTimestampsTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  test "converts legacy precisions using Tokyo wall-clock time, including 1950 daylight saving time" do
    migration = ExpandFuzzyTimestamps.new

    assert_equal "1979", migration.timestamp_from(Time.zone.local(1979, 4, 7), "year")
    assert_equal "1979-04", migration.timestamp_from(Time.zone.local(1979, 4, 7), "month")
    # 当時の東京は夏時間 (+10)。固定 +9 なら 7/14 になってしまう境界値。
    assert_equal "1950-07-15", migration.timestamp_from(Time.utc(1950, 7, 14, 14, 30), "day")
    assert_equal "1979-04-07T14:30", migration.timestamp_from(Time.zone.local(1979, 4, 7, 14, 30), "time")
  end

  test "restores a reduced timestamp to the legacy pair" do
    migration = ExpandFuzzyTimestamps.new

    time, precision = migration.legacy_from("1950-07-15")
    assert_equal Time.zone.local(1950, 7, 15), time
    assert_equal "day", precision

    time, precision = migration.legacy_from("1979-04-07T14:30")
    assert_equal Time.zone.local(1979, 4, 7, 14, 30), time
    assert_equal "time", precision
  end
end
