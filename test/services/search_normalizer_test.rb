require "test_helper"

class SearchNormalizerTest < ActiveSupport::TestCase
  CASES = {
    "全角英数を半角に" => [ "ＧＵＮＤＡＭ １９７９", "gundam 1979" ],
    "半角カナを全角カナに" => [ "ｶﾞﾝﾀﾞﾑ", "ガンダム" ],
    "ひらがなをカタカナに" => [ "がんだむ", "ガンダム" ],
    "ゔ" => [ "ゔぁいおりん", "ヴァイオリン" ],
    "長音・ダッシュ類を ー に" => [ "コンピュ－タ—ズ–〜～", "コンピューターズーーー" ],
    "ASCII のハイフンは折らない（p.1-10 等の識別子を守る）" => [ "p.1-10", "p.1-10" ],
    "大文字を小文字に" => [ "Gundam", "gundam" ],
    "連続空白と前後空白" => [ "  富野   由悠季 \n", "富野 由悠季" ],
    "カタカナはそのまま" => [ "ガンダム", "ガンダム" ]
  }.freeze

  CASES.each do |name, (input, expected)|
    test name do
      assert_equal expected, SearchNormalizer.call(input)
    end
  end

  test "nil は空文字" do
    assert_equal "", SearchNormalizer.call(nil)
  end

  test "冪等" do
    once = SearchNormalizer.call("ＧＵＮＤＡＭ がんだむ ｶﾞﾝﾀﾞﾑ")
    assert_equal once, SearchNormalizer.call(once)
  end
end
