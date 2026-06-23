require "test_helper"

class StatSnapshotTest < ActiveSupport::TestCase
  setup { @user = User.create!(email_address: "ss@example.com", name: "SS", provider: "discord", uid: "snap-u") }

  test "capture! records the current counts for today" do
    Article.create!(title: "S記事", created_by: @user)
    Material.create!(user: @user, url: "https://example.com/s", title: "S資料")

    snap = StatSnapshot.capture!
    assert_equal Date.current, snap.date
    assert_equal 1, snap.articles_count
    assert_equal 1, snap.materials_count
    assert_equal 0, snap.transcribed_chars
  end

  test "capture! records total file bytes and total pages" do
    m = Material.new(user: @user, title: "PDF")
    m.file.attach(io: StringIO.new("%PDF-1.4"), filename: "doc.pdf", content_type: "application/pdf")
    m.save!
    m.update_column(:page_count, 3)

    snap = StatSnapshot.capture!
    assert_equal "%PDF-1.4".bytesize, snap.total_file_bytes
    assert_equal 3, snap.total_pages   # PDF 3ページ + 画像0
  end

  test "capture! is idempotent per date (re-run updates the same row)" do
    StatSnapshot.capture!
    Article.create!(title: "後から", created_by: @user)
    assert_no_difference "StatSnapshot.count" do
      StatSnapshot.capture!
    end
    assert_equal 1, StatSnapshot.find_by!(date: Date.current).articles_count
  end
end
