require "test_helper"

class FuzzyDateTest < ActiveSupport::TestCase
  test "from_parts with year only -> year precision normalized to Jan 1" do
    fd = FuzzyDate.from_parts(year: 1979, month: nil, day: nil, hour: nil, minute: nil)
    assert_equal "year", fd.precision
    assert_equal Time.zone.local(1979, 1, 1, 0, 0), fd.at
    assert_equal "1979年", fd.label
  end

  test "from_parts with year and month -> month precision" do
    fd = FuzzyDate.from_parts(year: 1979, month: 5, day: nil, hour: nil, minute: nil)
    assert_equal "month", fd.precision
    assert_equal Time.zone.local(1979, 5, 1, 0, 0), fd.at
    assert_equal "1979年5月", fd.label
  end

  test "from_parts with full date -> day precision" do
    fd = FuzzyDate.from_parts(year: 1979, month: 5, day: 12, hour: nil, minute: nil)
    assert_equal "day", fd.precision
    assert_equal Time.zone.local(1979, 5, 12, 0, 0), fd.at
    assert_equal "1979年5月12日", fd.label
  end

  test "from_parts with time -> time precision" do
    fd = FuzzyDate.from_parts(year: 1979, month: 5, day: 12, hour: 14, minute: 30)
    assert_equal "time", fd.precision
    assert_equal Time.zone.local(1979, 5, 12, 14, 30), fd.at
    assert_equal "1979年5月12日 14:30", fd.label
  end

  test "coarser blank ignores finer parts (month blank drops day)" do
    fd = FuzzyDate.from_parts(year: 1979, month: nil, day: 12, hour: nil, minute: nil)
    assert_equal "year", fd.precision
    assert_equal Time.zone.local(1979, 1, 1, 0, 0), fd.at
  end

  test "from_parts returns nil when year blank" do
    assert_nil FuzzyDate.from_parts(year: nil, month: 5, day: 12, hour: nil, minute: nil)
  end

  test "from_parts raises InvalidParts on non-numeric input" do
    assert_raises(FuzzyDate::InvalidParts) { FuzzyDate.from_parts(year: "abc", month: nil, day: nil, hour: nil, minute: nil) }
    assert_raises(FuzzyDate::InvalidParts) { FuzzyDate.from_parts(year: 2020, month: "x", day: nil, hour: nil, minute: nil) }
  end

  test "from_parts raises InvalidParts on out-of-range parts" do
    assert_raises(FuzzyDate::InvalidParts) { FuzzyDate.from_parts(year: 0, month: nil, day: nil, hour: nil, minute: nil) }
    assert_raises(FuzzyDate::InvalidParts) { FuzzyDate.from_parts(year: 2020, month: 99, day: nil, hour: nil, minute: nil) }
    assert_raises(FuzzyDate::InvalidParts) { FuzzyDate.from_parts(year: 2020, month: 0, day: nil, hour: nil, minute: nil) }
    assert_raises(FuzzyDate::InvalidParts) { FuzzyDate.from_parts(year: 2020, month: 1, day: 99, hour: nil, minute: nil) }
    assert_raises(FuzzyDate::InvalidParts) { FuzzyDate.from_parts(year: 2020, month: 1, day: 1, hour: 24, minute: nil) }
    assert_raises(FuzzyDate::InvalidParts) { FuzzyDate.from_parts(year: 2020, month: 1, day: 1, hour: 1, minute: 60) }
  end

  test "from_parts raises InvalidParts on an impossible calendar date" do
    assert_raises(FuzzyDate::InvalidParts) { FuzzyDate.from_parts(year: 2021, month: 2, day: 31, hour: nil, minute: nil) }
  end

  test "wrap returns nil when at or precision nil" do
    assert_nil FuzzyDate.wrap(nil, "year")
    assert_nil FuzzyDate.wrap(Time.zone.local(1979), nil)
  end

  test "wrap builds label from stored at and precision" do
    fd = FuzzyDate.wrap(Time.zone.local(1979, 5, 1, 0, 0), "month")
    assert_equal "1979年5月", fd.label
  end

  test "slashes formats by precision with digits and separators (no kanji)" do
    assert_equal "1979", FuzzyDate.wrap(Time.zone.local(1979), "year").slashes
    assert_equal "1979/05", FuzzyDate.wrap(Time.zone.local(1979, 5), "month").slashes
    assert_equal "1979/05/12", FuzzyDate.wrap(Time.zone.local(1979, 5, 12), "day").slashes
    assert_equal "1979/05/12 14:30", FuzzyDate.wrap(Time.zone.local(1979, 5, 12, 14, 30), "time").slashes
  end
end
