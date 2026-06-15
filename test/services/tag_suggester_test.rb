require "test_helper"

class TagSuggesterTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(email_address: "ts@example.com", name: "TS", provider: "discord", uid: "tag-s")
    @gundam = Tag.create!(name: "ガンダム")
    @pamph = Tag.create!(name: "パンフレット")
    @unrelated = Tag.create!(name: "イデオン")
  end

  test "suggests existing tags that appear in the material text (incl. transcription)" do
    m = Material.new(user: @user, title: "ガンダム記録全集")
    m.file.attach(io: StringIO.new("x"), filename: "a.mp3", content_type: "audio/mpeg")
    m.save!
    Transcription.create!(material: m, author: @user, body: "劇場パンフレットの記述より", status: "drafting")

    assert_equal [ @gundam, @pamph ].map(&:name).sort, TagSuggester.call(m).map(&:name).sort
  end

  test "suggests tags found in any transcription part body" do
    m = create(:material, :with_audio)
    m.transcriptions.create!(author: @user, body: "本編は無関係", position: 1)
    m.transcriptions.create!(author: @user, body: "後半にパンフレットが出る", position: 2)
    assert_includes TagSuggester.call(m), @pamph
  end

  test "excludes tags already attached" do
    m = Material.create!(user: @user, url: "https://example.com/t", title: "ガンダム特集")
    m.tag_names = "ガンダム"
    m.save!
    assert_empty TagSuggester.call(m)
  end

  test "suggests from article title and current body" do
    a = Article.create!(title: "イデオン発動篇", created_by: @user)
    ArticleRevisionCreator.call(article: a, body: "ガンダムとの比較", author: @user)
    assert_equal [ @gundam, @unrelated ].map(&:name).sort, TagSuggester.call(a).map(&:name).sort
  end

  test "suggests from bibliographic metadata and comments (incl. auto-extract comments)" do
    m = Material.create!(user: @user, url: "https://example.com/m", title: "無題",
                         publisher: "ガンダム出版")
    m.comments.create!(author: @user, body: "📄 自動抽出した候補です:\n・タイトル (PDF): イデオン記録")
    assert_equal %w[イデオン ガンダム], TagSuggester.call(m).map(&:name).sort
  end

  test "returns empty when nothing matches" do
    m = Material.create!(user: @user, url: "https://example.com/n", title: "無関係な資料")
    assert_empty TagSuggester.call(m)
  end
end
