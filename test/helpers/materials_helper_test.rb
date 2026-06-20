require "test_helper"

class MaterialsHelperTest < ActionView::TestCase
  setup do
    @user = User.create!(email_address: "mh@example.com", name: "MH", provider: "discord", uid: "mh")
  end

  test "media_kind_label maps each media kind to a Japanese label" do
    link = Material.create!(user: @user, url: "https://x.test/v")
    assert_equal "リンク", media_kind_label(link)

    audio = Material.new(user: @user, title: "a")
    audio.file.attach(io: StringIO.new("x"), filename: "a.mp3", content_type: "audio/mpeg")
    audio.save!
    assert_equal "音声", media_kind_label(audio)

    doc = Material.new(user: @user, title: "d")
    doc.file.attach(io: StringIO.new("%PDF-1.4"), filename: "d.pdf", content_type: "application/pdf")
    doc.save!
    assert_equal "文書", media_kind_label(doc)
  end
end
