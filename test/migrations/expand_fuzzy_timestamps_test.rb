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


  test "up converts a legacy row and down restores it" do
    migration = ExpandFuzzyTimestamps.new
    connection = ActiveRecord::Base.connection
    migration.down
    connection.execute("PRAGMA foreign_keys = OFF")
    connection.execute(<<~SQL)
      INSERT INTO articles
        (id, title, slug, created_by_id, starts_at, starts_precision, status, comments_count, likes_count, lock_version, created_at, updated_at)
      VALUES
        (999999, 'migration test', 'migration-test', 999999, '1950-07-14 14:30:00', 'day', 'stub', 0, 0, 0,
         CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
    SQL

    migration.up
    assert_equal "1950-07-15", connection.select_value("SELECT starts FROM articles WHERE id = 999999")

    migration.down
    row = connection.select_one("SELECT starts_at, starts_precision FROM articles WHERE id = 999999")
    assert_equal "day", row.fetch("starts_precision")
    restored = Time.utc(*row.fetch("starts_at").scan(/\d+/).first(6).map(&:to_i)).in_time_zone
    assert_equal Time.zone.local(1950, 7, 15), restored
  ensure
    if connection&.column_exists?(:articles, :starts)
      connection.execute("DELETE FROM articles WHERE id = 999999")
    else
      connection&.execute("DELETE FROM articles WHERE id = 999999")
      migration&.up
    end
    connection&.execute("PRAGMA foreign_keys = ON")
    [ Article, Material, Publication ].each(&:reset_column_information)
  end

  test "down clears the legacy pair when the reduced timestamp was cleared after up" do
    migration = ExpandFuzzyTimestamps.new
    connection = ActiveRecord::Base.connection
    migration.down
    connection.execute("PRAGMA foreign_keys = OFF")
    connection.execute(<<~SQL)
      INSERT INTO articles
        (id, title, slug, created_by_id, starts_at, starts_precision, status, comments_count, likes_count, lock_version, created_at, updated_at)
      VALUES
        (999998, 'cleared migration test', 'cleared-migration-test', 999998, '1979-04-07 00:00:00', 'day', 'stub', 0, 0, 0,
         CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
    SQL

    migration.up
    connection.execute("UPDATE articles SET starts = NULL WHERE id = 999998")
    migration.down

    row = connection.select_one("SELECT starts_at, starts_precision FROM articles WHERE id = 999998")
    assert_nil row.fetch("starts_at")
    assert_nil row.fetch("starts_precision")
  ensure
    connection&.execute("DELETE FROM articles WHERE id = 999998")
    migration&.up unless connection&.column_exists?(:articles, :starts)
    connection&.execute("PRAGMA foreign_keys = ON")
    [ Article, Material, Publication ].each(&:reset_column_information)
  end
end
