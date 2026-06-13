require "test_helper"

class MaterialPostProcessJobTest < ActiveJob::TestCase
  # pdf-reader が page_count=1 と読め、かつ qpdf が linearize できる最小PDF
  def one_page_pdf
    objects = [
      "1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n",
      "2 0 obj\n<< /Type /Pages /Kids [3 0 R] /Count 1 >>\nendobj\n",
      "3 0 obj\n<< /Type /Page /Parent 2 0 R /MediaBox [0 0 10 10] >>\nendobj\n"
    ]
    head = "%PDF-1.4\n"
    offsets = []
    pos = head.bytesize
    objects.each { |o| offsets << pos; pos += o.bytesize }
    xref = "xref\n0 4\n0000000000 65535 f \n" + offsets.map { |o| format("%010d 00000 n \n", o) }.join
    trailer = "trailer\n<< /Size 4 /Root 1 0 R >>\nstartxref\n#{pos}\n%%EOF"
    StringIO.new(head + objects.join + xref + trailer)
  end

  test "perform extracts page_count and linearizes the pdf" do
    user = User.create!(email_address: "job@example.com", name: "Job", provider: "discord", uid: "job-u")
    m = Material.new(user: user, title: "PDF")
    m.file.attach(io: one_page_pdf, filename: "doc.pdf", content_type: "application/pdf")
    m.save!
    assert_nil m.page_count

    MaterialPostProcessJob.perform_now(m)

    assert_equal 1, m.reload.page_count, "抽出が走り page_count が入る"
    m.file.open { |f| assert PdfLinearizer.linearized?(f.path), "linearize が走る" }
  end

  test "perform is a safe no-op when no file is attached" do
    user = User.create!(email_address: "job2@example.com", name: "Job2", provider: "discord", uid: "job-u2")
    link = Material.create!(user: user, url: "https://example.com/x", title: "リンク")
    assert_nothing_raised { MaterialPostProcessJob.perform_now(link) }
  end
end
