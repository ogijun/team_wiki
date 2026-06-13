require "test_helper"

class PdfLinearizerTest < ActiveSupport::TestCase
  # qpdf が受理できる最小の有効 PDF（非linearize）を組み立てて一時ファイルに置く
  def write_one_page_pdf
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
    path = File.join(Dir.tmpdir, "src-#{SecureRandom.hex(4)}.pdf")
    File.binwrite(path, head + objects.join + xref + trailer)
    path
  end

  test "linearize produces a linearized PDF detected by linearized?" do
    src = write_one_page_pdf
    assert_not PdfLinearizer.linearized?(src), "入力は非linearize"
    out = PdfLinearizer.linearize(src)
    assert out, "出力パスが返る"
    assert PdfLinearizer.linearized?(out), "出力は linearized"
  ensure
    [ src, out ].each { |p| File.unlink(p) if p && File.exist?(p) }
  end

  test "linearize returns nil for a broken pdf" do
    path = File.join(Dir.tmpdir, "broken-#{SecureRandom.hex(4)}.pdf")
    File.binwrite(path, "%PDF-1.4 broken not really a pdf")
    assert_nil PdfLinearizer.linearize(path)
  ensure
    File.unlink(path) if File.exist?(path)
  end

  test "linearized? is false for a non-pdf or unreadable path" do
    assert_not PdfLinearizer.linearized?("/no/such/file.pdf")
  end
end
