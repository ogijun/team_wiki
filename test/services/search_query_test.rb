require "test_helper"

class SearchQueryTest < ActiveSupport::TestCase
  test "空白区切りは AND" do
    q = SearchQuery.parse("富野由悠季 ガンダム")
    assert_equal %w[富野由悠季 ガンダム], q.terms
    assert_equal '"富野由悠季" AND "ガンダム"', q.to_fts5
  end

  test "二重引用符はフレーズ" do
    q = SearchQuery.parse('"機動戦士ガンダム" 富野由悠季')
    assert_equal [ "機動戦士ガンダム" ], q.phrases
    assert_equal [ "富野由悠季" ], q.terms
    assert_equal '"富野由悠季" AND "機動戦士ガンダム"', q.to_fts5
  end

  test "先頭 - は除外。NOT は末尾にまとまる" do
    q = SearchQuery.parse("富野由悠季 -劇場版 ガンダム")
    assert_equal [ "劇場版" ], q.excludes
    assert_equal '"富野由悠季" AND "ガンダム" NOT "劇場版"', q.to_fts5
  end

  test "3文字未満の語は short 側に振り分ける（境界: 2文字は short、3文字は通常）" do
    q = SearchQuery.parse("富野 ガンダム -映画 -劇場版")
    assert_equal [ "富野" ], q.short_terms
    assert_equal [ "ガンダム" ], q.terms
    assert_equal [ "映画" ], q.short_excludes
    assert_equal [ "劇場版" ], q.excludes
    assert_equal '"ガンダム" NOT "劇場版"', q.to_fts5
  end

  test "全語が短ければ fts? は偽で to_fts5 は空" do
    q = SearchQuery.parse("富野 映画")
    assert_not q.fts?
    assert_equal "", q.to_fts5
    assert_equal %w[富野 映画], q.short_terms
  end

  test "正規化を通してから文字数を数える（全角英字3文字は通常の語）" do
    q = SearchQuery.parse("ＡＢＣ がんだむ")
    assert_equal %w[abc ガンダム], q.terms
  end

  test "FTS5 の記号は通常文字として扱い例外を出さない" do
    q = SearchQuery.parse("富野由悠季 (OR) AND NOT NEAR * : ^ +")
    assert_nothing_raised { q.to_fts5 }
    assert_includes q.to_fts5, '"富野由悠季"'
    assert_not_includes q.terms, "AND"
    assert_includes q.to_fts5, '"and"'
  end

  test "語の中の二重引用符は二重化してエスケープする" do
    q = SearchQuery.parse('富野"由悠季')
    assert_equal '"富野""由悠季"', q.to_fts5
  end

  test "閉じない引用符は通常の語として扱う" do
    q = SearchQuery.parse('"機動戦士 ガンダム')
    assert_equal [], q.phrases
    assert_equal %w[機動戦士 ガンダム], q.terms
  end

  test "空・空白のみは blank?" do
    assert_predicate SearchQuery.parse(""), :blank?
    assert_predicate SearchQuery.parse("   "), :blank?
    assert_predicate SearchQuery.parse(nil), :blank?
  end

  test "expand は恒等（同義語辞書の差し込み口）" do
    assert_equal [ "ガンダム" ], SearchQuery.parse("x").expand("ガンダム")
  end
end
