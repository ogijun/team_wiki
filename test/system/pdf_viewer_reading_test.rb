require "application_system_test_case"

class PdfViewerReadingTest < ApplicationSystemTestCase
  setup do
    @user = create(:user)
    @material = Material.new(user: @user, title: "読み上げPDF")
    @material.file.attach(
      io: StringIO.new(text_pdf("Readable PDF text")),
      filename: "readable.pdf",
      content_type: "application/pdf"
    )
    @material.save!
  end

  test "dialog exposes the current page text and fallback links" do
    sign_in_through_ui(@user)
    visit material_path(@material)
    click_on "readable.pdf"

    assert_selector "dialog[open][aria-labelledby='pdf-viewer-title-#{@material.id}']"
    assert_selector "[data-pdf-target=accessibleText][role=document]",
      text: "Readable PDF text", visible: :all
    within "dialog[open]" do
      assert_link "PDFを別タブで開く", href: pdf_material_path(@material)
      assert_link "PDFをダウンロード", href: rails_blob_path(@material.file)
    end
  end

  private

  def text_pdf(text)
    stream = "BT /F1 18 Tf 72 720 Td (#{text}) Tj ET"
    objects = [
      "1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n",
      "2 0 obj\n<< /Type /Pages /Kids [3 0 R] /Count 1 >>\nendobj\n",
      "3 0 obj\n<< /Type /Page /Parent 2 0 R /MediaBox [0 0 600 800] " \
        "/Resources << /Font << /F1 4 0 R >> >> /Contents 5 0 R >>\nendobj\n",
      "4 0 obj\n<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>\nendobj\n",
      "5 0 obj\n<< /Length #{stream.bytesize} >>\nstream\n#{stream}\nendstream\nendobj\n"
    ]
    pdf = +"%PDF-1.4\n"
    offsets = objects.map { |object| pdf.bytesize.tap { pdf << object } }
    xref = pdf.bytesize
    pdf << "xref\n0 6\n0000000000 65535 f \n"
    offsets.each { |offset| pdf << format("%010d 00000 n \n", offset) }
    pdf << "trailer\n<< /Size 6 /Root 1 0 R >>\nstartxref\n#{xref}\n%%EOF\n"
  end
end
