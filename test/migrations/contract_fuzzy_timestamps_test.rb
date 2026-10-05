require "test_helper"
require Rails.root.join("db/migrate/20261001000001_contract_fuzzy_timestamps")

class ContractFuzzyTimestampsTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  LEGACY_COLUMNS = {
    articles: %i[starts_at starts_precision ends_at ends_precision],
    materials: %i[published_at published_precision],
    publications: %i[released_at released_precision]
  }.freeze
  LEGACY_INDEXES = {
    articles: "index_articles_on_starts_at",
    materials: "index_materials_on_published_at",
    publications: "index_publications_on_released_at"
  }.freeze

  test "up down up removes and restores legacy columns and indexes including a 1950 day" do
    migration = ContractFuzzyTimestamps.new
    connection = ActiveRecord::Base.connection
    migration.down
    connection.execute("PRAGMA foreign_keys = OFF")
    connection.execute(<<~SQL)
      INSERT INTO articles
        (id, title, slug, created_by_id, starts, ends, status, comments_count, likes_count, lock_version, created_at, updated_at)
      VALUES
        (999997, 'contract migration test', 'contract-migration-test', 999997, '1950-07-15', '1979', 'stub', 0, 0, 0,
         CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
    SQL
    connection.execute(<<~SQL)
      INSERT INTO materials (id, title, slug, user_id, url, published, created_at, updated_at)
      VALUES (999997, 'contract material', 'contract-material', 999997, 'https://example.com/contract', '1979-04',
              CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
    SQL
    connection.execute(<<~SQL)
      INSERT INTO publications (id, title, kind, registered_by_id, released, created_at, updated_at)
      VALUES (999997, 'contract publication', 'book', 999997, '1979-04-07T14:30',
              CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
    SQL

    migration.up
    assert_legacy_schema(false)

    migration.down
    assert_legacy_schema(true)
    assert_legacy_value(:articles, 999997, :starts_at, :starts_precision, "day", Time.zone.local(1950, 7, 15))
    assert_legacy_value(:articles, 999997, :ends_at, :ends_precision, "year", Time.zone.local(1979, 1, 1))
    assert_legacy_value(:materials, 999997, :published_at, :published_precision, "month", Time.zone.local(1979, 4, 1))
    assert_legacy_value(:publications, 999997, :released_at, :released_precision, "time", Time.zone.local(1979, 4, 7, 14, 30))

    migration.up
    assert_legacy_schema(false)
  ensure
    %i[articles materials publications].each do |table|
      connection&.execute("DELETE FROM #{table} WHERE id = 999997")
    end
    migration&.up if connection&.column_exists?(:articles, :starts_at)
    connection&.execute("PRAGMA foreign_keys = ON")
    [ Article, Material, Publication ].each(&:reset_column_information)
  end

  private

  def assert_legacy_schema(expected)
    connection = ActiveRecord::Base.connection
    LEGACY_COLUMNS.each do |table, columns|
      columns.each { |column| assert_equal expected, connection.column_exists?(table, column) }
    end
    LEGACY_INDEXES.each do |table, index|
      assert_equal expected, connection.index_exists?(table, name: index)
    end
  end

  def assert_legacy_value(table, id, at, precision, expected_precision, expected_time)
    row = ActiveRecord::Base.connection.select_one("SELECT #{at}, #{precision} FROM #{table} WHERE id = #{id}")
    assert_equal expected_precision, row.fetch(precision.to_s)
    restored = Time.utc(*row.fetch(at.to_s).scan(/\d+/).first(6).map(&:to_i)).in_time_zone
    assert_equal expected_time, restored
  end
end
