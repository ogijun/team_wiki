require "test_helper"

class TagSuggesterTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(email_address: "ts@example.com", name: "TS", provider: "discord", uid: "tag-s")
    @space = Tag.create!(name: "宇宙")
    @pamph = Tag.create!(name: "パンフレット")
    @unrelated = Tag.create!(name: "歴史")
  end

  test "suggests existing tags that appear in the material text (incl. transcription)" do
    m = Material.new(user: @user, title: "宇宙記録全集")
    m.file.attach(io: StringIO.new("x"), filename: "a.mp3", content_type: "audio/mpeg")
    m.save!
    Transcription.create!(material: m, author: @user, body: "劇場パンフレットの記述より", status: "drafting")

    assert_equal [ @space, @pamph ].map(&:name).sort, TagSuggester.call(m).map(&:name).sort
  end

  test "suggests tags found in any transcription part body" do
    m = create(:material, :with_audio)
    m.transcriptions.create!(author: @user, body: "本編は無関係", position: 1)
    m.transcriptions.create!(author: @user, body: "後半にパンフレットが出る", position: 2)
    assert_includes TagSuggester.call(m), @pamph
  end

  test "excludes tags already attached" do
    m = Material.create!(user: @user, url: "https://example.com/t", title: "宇宙特集")
    m.tag_names = "宇宙"
    m.save!
    assert_empty TagSuggester.call(m)
  end

  test "suggests from article title and current body" do
    a = Article.create!(title: "歴史総集篇", created_by: @user)
    ArticleRevisionCreator.call(article: a, body: "宇宙との比較", author: @user)
    assert_equal [ @space, @unrelated ].map(&:name).sort, TagSuggester.call(a).map(&:name).sort
  end

  test "suggests from bibliographic metadata and comments" do
    m = Material.create!(user: @user, url: "https://example.com/m", title: "無題",
                         publisher: "宇宙出版")
    m.comments.create!(author: @user, body: "メモ:\n・タイトル (PDF): 歴史記録")
    assert_equal %w[宇宙 歴史], TagSuggester.call(m).map(&:name).sort
  end

  test "returns empty when nothing matches" do
    m = Material.create!(user: @user, url: "https://example.com/n", title: "無関係な資料")
    assert_empty TagSuggester.call(m)
  end
end
