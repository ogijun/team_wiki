require "test_helper"

class PublicationTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(email_address: "pub@example.com", name: "Pub", provider: "discord", uid: "pub-user")
  end

  def build(**attrs)
    Publication.new({ title: "サンプル 文庫版", kind: "book", registered_by: @user }.merge(attrs))
  end

  test "title is required" do
    pub = build(title: "")
    assert_not pub.valid?
    assert_includes pub.errors.attribute_names, :title
  end

  test "kind must be one of KINDS" do
    assert_not build(kind: "bogus").valid?
    assert_predicate build(kind: "video"), :valid?
  end

  test "sales_status defaults to on_sale and must be valid" do
    pub = build
    pub.save!
    assert_equal "on_sale", pub.sales_status
    pub.sales_status = "bogus"
    assert_not pub.valid?
  end

  test "store_url must be http(s) when present" do
    assert_not build(store_url: "ftp://example.com").valid?
    assert_predicate build(store_url: "https://example.com/item"), :valid?
    assert_predicate build(store_url: ""), :valid?, "空文字は nil 扱いで許容する"
  end

  test "released fuzzy date is built from parts" do
    pub = build(released_year: "1995", released_month: "3")
    pub.save!
    assert_equal "month", pub.released_precision
    assert_equal 1995, pub.released_at.year
    assert_equal 3, pub.released_at.month
  end

  test "invalid date parts become a validation error, not an exception" do
    pub = build(released_year: "1995", released_month: "13")
    assert_not pub.valid?
  end

  test "chronicled returns only dated publications, ordered" do
    later = Publication.create!(title: "後", kind: "book", registered_by: @user, released_year: "2000")
    earlier = Publication.create!(title: "先", kind: "book", registered_by: @user, released_year: "1990")
    Publication.create!(title: "日付なし", kind: "book", registered_by: @user)
    assert_equal [ earlier, later ], Publication.chronicled.to_a
  end

  test "purchasable? requires on_sale and a store_url" do
    assert_predicate build(sales_status: "on_sale", store_url: "https://example.com"), :purchasable?
    assert_not build(sales_status: "on_sale", store_url: nil).purchasable?
    assert_not build(sales_status: "out_of_print", store_url: "https://example.com").purchasable?
  end

  test "labels" do
    assert_equal "著書", build(kind: "book").kind_label
    assert_equal "販売中", build(sales_status: "on_sale").sales_status_label
  end

  test "authorization predicates allow any signed-in member" do
    pub = build
    assert pub.editable_by?(@user)
    assert pub.deletable_by?(@user)
    assert_not pub.editable_by?(nil)
  end

  # ── 書影（カバー画像）──
  def attach_cover(pub, io: StringIO.new("x"), filename: "cover.png", content_type: "image/png")
    pub.cover.attach(io: io, filename: filename, content_type: content_type)
    pub
  end

  test "cover: an image attaches and cover_thumbnail returns a representation" do
    pub = attach_cover(build)
    assert_predicate pub, :valid?, pub.errors.full_messages.join(", ")
    pub.save!
    assert_not_nil pub.cover_thumbnail(100)
  end

  test "cover_thumbnail is nil when no cover is attached" do
    pub = build
    pub.save!
    assert_nil pub.cover_thumbnail(100)
  end

  test "cover rejects a non-image content type" do
    pub = attach_cover(build, io: StringIO.new("%PDF-1.4"), filename: "doc.pdf", content_type: "application/pdf")
    assert_not pub.valid?
    assert_includes pub.errors[:cover], "は画像ファイル（PNG/JPEG/GIF/WebP）にしてください"

    txt = attach_cover(build, io: StringIO.new("hello"), filename: "a.txt", content_type: "text/plain")
    assert_not txt.valid?
    assert_predicate txt.errors[:cover], :any?
  end

  test "cover rejects a file larger than COVER_MAX_BYTES" do
    pub = attach_cover(build)
    # 実サイズのファイルは載せられないので byte_size をスタブして境界だけ検証する（material_test と同じ作法）。
    pub.cover.blob.define_singleton_method(:byte_size) { Publication::COVER_MAX_BYTES + 1 }
    assert_not pub.valid?
    assert pub.errors[:cover].any? { |msg| msg.include?("大きすぎ") }
  end

  test "cover accepts a file at exactly COVER_MAX_BYTES" do
    pub = attach_cover(build)
    pub.cover.blob.define_singleton_method(:byte_size) { Publication::COVER_MAX_BYTES }
    assert_predicate pub, :valid?, pub.errors.full_messages.join(", ")
  end
end
