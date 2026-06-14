require "test_helper"

class ActivityGrouperTest < ActiveSupport::TestCase
  setup do
    @user  = create(:user)
    @other = create(:user)
  end

  # created_at を明示して Activity を1件作る（subject 任意・label は subject.title で補完）。
  def act(action, at:, subject: nil, label: nil, user: @user)
    Activity.create!(user: user, action: action, subject: subject,
                     subject_label: label || subject&.title, created_at: at)
  end

  # 入力は created_at 降順（タイムライン表示順）であるべきなので、降順に並べて渡す。
  def desc(*activities)
    activities.sort_by(&:created_at).reverse
  end

  test "merges create then edit on the same subject into one :subject group" do
    article = create(:article, title: "ドキュメント")
    a1 = act("article.created", subject: article, at: 10.minutes.ago)
    a2 = act("article.edited",  subject: article, at: 5.minutes.ago)
    groups = ActivityGrouper.call(desc(a1, a2))
    assert_equal 1, groups.size
    assert_equal :subject, groups.first.kind
    assert_equal 2, groups.first.activities.size
  end

  test "groups consecutive same-action different-subject into one :action group" do
    mats = Array.new(5) { |k| create(:material, title: "資料#{k}") }
    acts = mats.each_with_index.map { |m, k| act("material.added", subject: m, at: (20 - k).minutes.ago) }
    groups = ActivityGrouper.call(desc(*acts))
    assert_equal 1, groups.size
    assert_equal :action, groups.first.kind
    assert_equal 5, groups.first.activities.size
  end

  test "splits when the gap exceeds the 30-minute window" do
    m1 = create(:material, title: "A")
    m2 = create(:material, title: "B")
    a1 = act("material.added", subject: m1, at: 90.minutes.ago)
    a2 = act("material.added", subject: m2, at: 5.minutes.ago)
    groups = ActivityGrouper.call(desc(a1, a2))
    assert_equal 2, groups.size
    assert(groups.all? { |g| g.kind == :single })
  end

  test "splits when another user's activity interleaves" do
    m1 = create(:material, title: "A")
    m2 = create(:material, title: "B")
    a1 = act("material.added", subject: m1, at: 15.minutes.ago)
    o  = act("material.added", subject: create(:material), at: 10.minutes.ago, user: @other)
    a2 = act("material.added", subject: m2, at: 5.minutes.ago)
    groups = ActivityGrouper.call(desc(a1, o, a2))
    assert_equal 3, groups.size
    assert(groups.all? { |g| g.kind == :single })
  end

  test "leaves a mixed run (different subject and action) as singles" do
    article = create(:article, title: "記事A")
    mat = create(:material, title: "資料B")
    a1 = act("article.created", subject: article, at: 15.minutes.ago)
    a2 = act("material.added",  subject: mat,     at: 10.minutes.ago)
    a3 = act("article.edited",  subject: article, at: 5.minutes.ago)
    groups = ActivityGrouper.call(desc(a1, a2, a3))
    assert_equal 3, groups.size
    assert(groups.all? { |g| g.kind == :single })
  end

  test "does not merge non-mergeable actions on the same subject" do
    mat = create(:material, title: "資料")
    a1 = act("material.added",        subject: mat, at: 10.minutes.ago)
    a2 = act("transcription.created", subject: mat, at: 5.minutes.ago)
    groups = ActivityGrouper.call(desc(a1, a2))
    assert_equal 2, groups.size
    assert(groups.all? { |g| g.kind == :single })
  end

  test "merges transcription create then edit on the same material" do
    mat = create(:material, title: "音声")
    a1 = act("transcription.created", subject: mat, at: 10.minutes.ago)
    a2 = act("transcription.edited",  subject: mat, at: 5.minutes.ago)
    groups = ActivityGrouper.call(desc(a1, a2))
    assert_equal 1, groups.size
    assert_equal :subject, groups.first.kind
  end

  test "groups consecutive deletes (nil subject) by action via subject_label" do
    a1 = act("material.deleted", label: "消A", at: 10.minutes.ago)
    a2 = act("material.deleted", label: "消B", at: 5.minutes.ago)
    groups = ActivityGrouper.call(desc(a1, a2))
    assert_equal 1, groups.size
    assert_equal :action, groups.first.kind
  end

  test "returns empty for empty input" do
    assert_equal [], ActivityGrouper.call([])
  end
end
