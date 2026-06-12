require "test_helper"

class MaterialMetadataExtractorTest < ActiveSupport::TestCase
  setup { @user = User.create!(email_address: "mx@example.com", name: "MX", provider: "discord", uid: "meta-u") }

  def attach_material(io, filename, content_type)
    m = Material.new(user: @user, title: "抽出対象")
    m.file.attach(io: io, filename: filename, content_type: content_type)
    m.save!
    m
  end

  def jpeg_with_exif(datetime)
    img = Vips::Image.black(2, 2).mutate do |m|
      m.set_type!(GObject::GSTR_TYPE, "exif-ifd2-DateTimeOriginal", datetime)
    end
    StringIO.new(img.write_to_buffer(".jpg"))
  end

  # Info 辞書つきの最小 PDF をオフセット計算込みで組み立てる
  def minimal_pdf(title:, author:, creation: "D:20200316100000+09'00'")
    objects = [
      "1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n",
      "2 0 obj\n<< /Type /Pages /Kids [3 0 R] /Count 1 >>\nendobj\n",
      "3 0 obj\n<< /Type /Page /Parent 2 0 R /MediaBox [0 0 10 10] >>\nendobj\n",
      "4 0 obj\n<< /Title (#{title}) /Author (#{author}) /CreationDate (#{creation}) >>\nendobj\n"
    ]
    head = "%PDF-1.4\n"
    offsets = []
    pos = head.bytesize
    objects.each { |o| offsets << pos; pos += o.bytesize }
    xref = "xref\n0 5\n0000000000 65535 f \n" + offsets.map { |o| format("%010d 00000 n \n", o) }.join
    trailer = "trailer\n<< /Size 5 /Root 1 0 R /Info 4 0 R >>\nstartxref\n#{pos}\n%%EOF"
    StringIO.new(head + objects.join + xref + trailer)
  end

  EMPTY = { file_created_at: nil, details: {} }.freeze

  test "extracts the EXIF capture time from an image" do
    m = attach_material(jpeg_with_exif("2020:03:16 10:00:00"), "photo.jpg", "image/jpeg")
    result = MaterialMetadataExtractor.call(m)
    assert_equal Time.zone.local(2020, 3, 16, 10, 0), result[:file_created_at]
    assert_equal "2020年3月16日 10:00", result[:details]["撮影日時 (EXIF)"]
  end

  test "extracts title, author, creation date and page count from a PDF" do
    m = attach_material(minimal_pdf(title: "Sample Doc 4", author: "Sample Writer"), "doc.pdf", "application/pdf")
    result = MaterialMetadataExtractor.call(m)
    assert_equal Time.zone.local(2020, 3, 16, 10, 0), result[:file_created_at]
    assert_equal "Sample Doc 4", result[:details]["タイトル (PDF)"]
    assert_equal "Sample Writer", result[:details]["作成者 (PDF)"]
    assert_equal "2020年3月16日 10:00", result[:details]["作成日 (PDF)"]
    assert_equal "1", result[:details]["ページ数 (PDF)"]
  end

  test "returns empty for links, exif-less images, and broken files" do
    link = Material.create!(user: @user, url: "https://example.com/x", title: "リンク")
    assert_equal EMPTY, MaterialMetadataExtractor.call(link)

    plain = attach_material(StringIO.new(Vips::Image.black(2, 2).write_to_buffer(".png")), "p.png", "image/png")
    assert_equal EMPTY, MaterialMetadataExtractor.call(plain)

    broken = attach_material(StringIO.new("%PDF-1.4 broken"), "b.pdf", "application/pdf")
    assert_equal EMPTY, MaterialMetadataExtractor.call(broken)
  end
end
