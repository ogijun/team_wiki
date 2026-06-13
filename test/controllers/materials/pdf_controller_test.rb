require "test_helper"

class Materials::PdfControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(email_address: "pdf@example.com", name: "PDF", provider: "discord", uid: "pdf-u")
    sign_in_as(@user)
    @material = Material.new(user: @user, title: "PDF")
    @material.file.attach(io: one_page_pdf, filename: "doc.pdf", content_type: "application/pdf")
    @material.save!
  end

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

  test "full request carries Content-Length and Accept-Ranges so PDF.js can enable range mode" do
    get pdf_material_url(@material)
    assert_response :success
    assert_equal @material.file.blob.byte_size.to_s, response.headers["Content-Length"]
    assert_equal "bytes", response.headers["Accept-Ranges"]
    assert_equal "application/pdf", response.media_type
  end

  test "range request returns 206 with Content-Range and a sized partial" do
    get pdf_material_url(@material), headers: { "Range" => "bytes=0-9" }
    assert_response 206
    assert_match %r{\Abytes 0-9/\d+\z}, response.headers["Content-Range"]
    assert_equal "10", response.headers["Content-Length"]
  end

  test "non-pdf material is not found" do
    img = Material.new(user: @user, title: "img")
    img.file.attach(io: StringIO.new("x"), filename: "a.png", content_type: "image/png")
    img.save!
    get pdf_material_url(img)
    assert_response :not_found
  end

  test "requires login" do
    delete session_url
    get pdf_material_url(@material)
    assert_redirected_to new_session_url
  end
end
