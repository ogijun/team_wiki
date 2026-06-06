require "test_helper"

class ApplicationHelperTest < ActionView::TestCase
  test "fuzzy_part returns parts up to the precision, nil beyond" do
    day = FuzzyDate.wrap(Time.zone.local(1979, 4, 7), "day")
    assert_equal 1979, fuzzy_part(day, :year)
    assert_equal 4, fuzzy_part(day, :month)
    assert_equal 7, fuzzy_part(day, :day)
    assert_nil fuzzy_part(day, :hour)
    assert_nil fuzzy_part(day, :minute)
  end

  test "fuzzy_part with year precision hides finer parts" do
    year = FuzzyDate.wrap(Time.zone.local(1979), "year")
    assert_equal 1979, fuzzy_part(year, :year)
    assert_nil fuzzy_part(year, :month)
    assert_nil fuzzy_part(year, :day)
  end

  test "fuzzy_part with time precision exposes hour and minute" do
    t = FuzzyDate.wrap(Time.zone.local(1979, 4, 7, 9, 30), "time")
    assert_equal 9, fuzzy_part(t, :hour)
    assert_equal 30, fuzzy_part(t, :minute)
  end

  test "fuzzy_part of nil is nil" do
    assert_nil fuzzy_part(nil, :year)
  end
end
