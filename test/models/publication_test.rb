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
end
