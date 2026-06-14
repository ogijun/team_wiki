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

  test "compact_date drops the year in the current year, keeps it otherwise" do
    this_year = Time.zone.local(Date.current.year, 6, 14, 13, 38)
    assert_equal "06/14", compact_date(this_year)
    assert_equal "2000/03/01", compact_date(Time.zone.local(2000, 3, 1))
  end

  test "brand_name falls back to default when setting blank" do
    SiteSetting.instance.update!(brand_name: nil)
    assert_equal "Team Wiki", brand_name
  end

  test "brand_name uses the setting value when present" do
    SiteSetting.instance.update!(brand_name: "サンプルWiki")
    assert_equal "サンプルWiki", brand_name
  end

  test "brand_display is text when no logo, image when logo attached" do
    s = SiteSetting.instance
    s.update!(brand_name: "テキスト名")
    assert_equal "テキスト名", brand_display
    s.logo.attach(io: StringIO.new("x"), filename: "logo.png", content_type: "image/png")
    @site_setting = nil # 再読み込み
    assert_match(/<img /, brand_display)
  end
end
