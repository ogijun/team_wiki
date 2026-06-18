require "test_helper"

class ChronicleTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(email_address: "chr@example.com", name: "Chr", provider: "discord", uid: "chr")
  end

  test "entries merges dated articles and dated materials, ascending by date" do
    older_material = Material.create!(user: @user, title: "古い資料", url: "https://x.test/old",
                                      published_at: Time.utc(1979, 4, 1), published_precision: "month")
    article = Article.create_with_revision!(
      { title: "中間の記事", status: "stub", created_by: @user,
        starts_at: Time.utc(1981, 1, 1), starts_precision: "year" },
      body: "本文", author: @user
    )
    newer_material = Material.create!(user: @user, title: "新しい資料", url: "https://x.test/new",
                                      published_at: Time.utc(1982, 3, 1), published_precision: "month")
    # 発行日なしの資料・日付なしの記事は出ない
    Material.create!(user: @user, title: "日付なし資料", url: "https://x.test/none")
    Article.create_with_revision!({ title: "日付なし記事", status: "stub", created_by: @user }, body: "x", author: @user)

    entries = Chronicle.entries
    assert_equal [ "古い資料", "中間の記事", "新しい資料" ], entries.map(&:title)
    assert_equal [ :material, :article, :material ], entries.map(&:kind)
    assert_equal [ older_material, article, newer_material ], entries.map(&:record)
  end
end
