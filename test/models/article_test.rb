require "test_helper"

class ArticleTest < ActiveSupport::TestCase
  setup { @user = User.create!(email_address: "u@example.com", password: "password123", name: "U") }

  test "blank kind is normalized to nil (フォームの未分類=空文字を許容)" do
    a = Article.new(title: "未分類記事", created_by: @user, kind: "")
    assert_predicate a, :valid?, a.errors.full_messages.join(", ")
    assert_nil a.kind
  end

  test "invalid date parts make the record invalid instead of raising (500)" do
    a = Article.new(title: "不正日付記事", created_by: @user, start_year: "2020", start_month: "99")
    assert_nothing_raised { a.valid? }
    assert_not_predicate a, :valid?
    assert_nil a.starts_at
    assert_predicate a.errors, :any?
  end

  test "non-numeric date parts make the record invalid instead of raising" do
    a = Article.new(title: "数値以外日付記事", created_by: @user, start_year: "abc")
    assert_nothing_raised { a.valid? }
    assert_not_predicate a, :valid?
  end

  test "clearing all date parts removes the fuzzy date" do
    a = Article.create!(title: "日付クリア", created_by: @user, start_year: 1998)
    assert_predicate a.starts, :present?
    a.update!(start_year: "", start_month: "", start_day: "", start_hour: "", start_minute: "")
    assert_nil a.reload.starts_at
    assert_nil a.starts_precision
  end

  test "a save that does not touch date parts keeps the stored date" do
    a = Article.create!(title: "日付保持", created_by: @user, start_year: 1998)
    Article.find(a.id).update!(status: "done") # 仮想アクセサ未代入(=nil)の save
    assert_predicate a.reload.starts, :present?
  end

  test "contributors are distinct revision authors in first-appearance order" do
    bob = User.create!(email_address: "bob@example.com", password: "password123", name: "Bob")
    article = Article.create!(title: "共同編集", created_by: @user)
    article.revise!(body: "1", author: @user)
    article.revise!(body: "2", author: bob)
    article.revise!(body: "3", author: @user)
    assert_equal [ @user, bob ], article.contributors
  end

  test "requires title" do
    article = Article.new(created_by: @user)
    assert_not article.valid?
    assert_predicate article.errors[:title], :any?
  end

  test "slug is a random token not derived from title" do
    article = Article.create!(title: "これはテストページです", created_by: @user)
    assert_match(/\A[a-z0-9]{8}\z/, article.slug)
    assert_not_includes article.slug, "テスト"
  end

  test "slug is unique across articles" do
    a = Article.create!(title: "A", created_by: @user)
    b = Article.create!(title: "B", created_by: @user)
    assert_not_equal a.slug, b.slug
  end

  test "title uniqueness enforced" do
    Article.create!(title: "Same", created_by: @user)
    dup = Article.new(title: "Same", created_by: @user)
    assert_not dup.valid?
  end

  test "to_param returns slug" do
    article = Article.create!(title: "Param Me", created_by: @user)
    assert_equal article.slug, article.to_param
  end

  test "destroying an article removes its citations but keeps the cited material" do
    article = Article.create!(title: "NullifyMe", created_by: @user)
    m = Material.create!(user: @user, url: "https://example.com/x", title: "被引用資料")
    article.revise!(body: "[[ref:#{m.slug}]]", author: @user)
    assert_equal 1, m.reload.citing_articles.count

    article.destroy
    assert Material.exists?(m.id)
    assert_equal 0, Citation.where(material_id: m.id).count
  end

  test "destroying an article nullifies activities that point at it" do
    article = Article.create!(title: "活動対象", created_by: @user)
    act = Activity.record(actor: @user, action: "article.created", subject: article)

    article.destroy
    act.reload
    assert_nil act.subject_id
    assert_nil act.subject
    assert_equal "活動対象", act.subject_label # ラベルのスナップショットは残る
  end

  test "starts reader wraps stored columns into FuzzyDate" do
    a = Article.create!(title: "年表記事", created_by: @user,
                        starts_at: Time.zone.local(1979, 1, 1), starts_precision: "year")
    assert_equal "1979年", a.starts.label
    assert_nil a.ends
  end

  test "requires starts_at and starts_precision together" do
    a = Article.new(title: "片方", created_by: @user, starts_at: Time.zone.local(1979))
    assert_not a.valid?
    assert_predicate a.errors[:starts_precision], :any?
  end

  test "rejects invalid precision" do
    a = Article.new(title: "不正精度", created_by: @user,
                    starts_at: Time.zone.local(1979), starts_precision: "decade")
    assert_not a.valid?
  end

  test "ends must not precede starts" do
    a = Article.new(title: "逆転", created_by: @user,
                    starts_at: Time.zone.local(1980), starts_precision: "year",
                    ends_at: Time.zone.local(1979), ends_precision: "year")
    assert_not a.valid?
    assert_predicate a.errors[:ends_at], :any?
  end

  test "ends requires starts" do
    a = Article.new(title: "終わりだけ", created_by: @user,
                    ends_at: Time.zone.local(1979), ends_precision: "year")
    assert_not a.valid?
    assert_predicate a.errors[:starts_at], :any?
  end

  test "chronicled scope returns dated articles oldest first" do
    Article.create!(title: "無日付", created_by: @user)
    newer = Article.create!(title: "1990", created_by: @user,
                            starts_at: Time.zone.local(1990), starts_precision: "year")
    older = Article.create!(title: "1980", created_by: @user,
                            starts_at: Time.zone.local(1980), starts_precision: "year")
    assert_equal [ older, newer ], Article.chronicled.to_a
  end

  test "default status is stub" do
    article = Article.create!(title: "状態既定", created_by: @user)
    assert_equal "stub", article.status
  end

  test "status must be one of STATUSES" do
    article = Article.new(title: "状態不正", created_by: @user, status: "bogus")
    assert_not article.valid?
    assert_predicate article.errors[:status], :any?
  end

  test "kind allows nil and valid values, rejects others" do
    assert_predicate Article.new(title: "k1", created_by: @user, kind: nil), :valid?
    assert_predicate Article.new(title: "k2", created_by: @user, kind: "work"), :valid?
    bad = Article.new(title: "k3", created_by: @user, kind: "bogus")
    assert_not bad.valid?
    assert_predicate bad.errors[:kind], :any?
  end

  test "labels map slug to Japanese, nil kind is 未分類" do
    a = Article.new(title: "ラベル", created_by: @user, kind: "person", status: "writing")
    assert_equal "人物", a.kind_label
    assert_equal "執筆中", a.status_label
    assert_equal "未分類", Article.new(title: "x", created_by: @user, kind: nil).kind_label
  end
end
