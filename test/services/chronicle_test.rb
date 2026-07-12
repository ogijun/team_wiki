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

  test "publications with a release date join the timeline in date order" do
    article = Article.create!(title: "1990年の記事", created_by: @user, start_year: "1990")
    pub = Publication.create!(title: "1995年の本", kind: "book", registered_by: @user, released_year: "1995")

    entries = Chronicle.entries
    assert_equal [ article, pub ], entries.map(&:record)
    assert_equal :publication, entries.last.kind
    assert_equal "1995年の本", entries.last.title
  end

  test "publications without a release date are excluded" do
    Publication.create!(title: "日付なし", kind: "book", registered_by: @user)
    assert_empty Chronicle.entries
  end

  test "same-day entries are ordered article, material, publication" do
    Publication.create!(title: "同日の発売", kind: "book", registered_by: @user, released_year: "2000")
    Article.create!(title: "同日の記事", created_by: @user, start_year: "2000")

    kinds = Chronicle.entries.map(&:kind)
    assert_equal [ :article, :publication ], kinds
  end

  test "same-day entries put material between article and publication" do
    Publication.create!(title: "同日の発売", kind: "book", registered_by: @user, released_year: "2000")
    Material.create!(user: @user, title: "同日の資料", url: "https://x.test/same", published_year: "2000")
    Article.create!(title: "同日の記事", created_by: @user, start_year: "2000")

    kinds = Chronicle.entries.map(&:kind)
    assert_equal [ :article, :material, :publication ], kinds
  end
end
