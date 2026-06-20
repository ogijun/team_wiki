require "test_helper"

class MaterialsHelperTest < ActionView::TestCase
  setup do
    @user = User.create!(email_address: "mh@example.com", name: "MH", provider: "discord", uid: "mh")
  end

  test "material_kind_label uses user kind, else auto guess, else 未分類" do
    web = Material.create!(user: @user, url: "https://example.com/page")
    assert_equal "Webページ", material_kind_label(web)            # 非埋め込みURL→自動 web

    audio = Material.new(user: @user, title: "a")
    audio.file.attach(io: StringIO.new("x"), filename: "a.mp3", content_type: "audio/mpeg")
    audio.save!
    assert_equal "音声", material_kind_label(audio)               # 音声ファイル→自動 audio

    doc = Material.new(user: @user, title: "d")
    doc.file.attach(io: StringIO.new("%PDF-1.4"), filename: "d.pdf", content_type: "application/pdf")
    doc.save!
    assert_equal "未分類", material_kind_label(doc)               # PDFは推定不能

    doc.update!(kind: "book")
    assert_equal "書籍", material_kind_label(doc)                 # ユーザ選択が優先
  end
end
