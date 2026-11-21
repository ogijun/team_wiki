require "application_system_test_case"

class PdfViewerStatusTest < ApplicationSystemTestCase
  setup do
    @user = create(:user)
    @material = Material.new(user: @user, title: "状態通知PDF")
    @material.file.attach(
      io: StringIO.new(two_page_pdf),
      filename: "status.pdf",
      content_type: "application/pdf"
    )
    @material.save!
    sign_in_through_ui(@user)
  end

  test "announces the current page and disables navigation at page boundaries" do
    visit material_path(@material)
    click_on "status.pdf"

    assert_selector "dialog[aria-busy='false'] .pdf-viewer__stage canvas"
    assert_selector "button[data-action='pdf#prev'][aria-disabled='true']"
    assert_selector "button[data-action='pdf#next'][aria-disabled='false']"
    assert_selector "[data-pdf-target=announcement]", text: "PDF本文 1 / 2 ページ", visible: :all

    next_button = find("button[data-action='pdf#next']")
    next_button.click

    assert_selector "[data-pdf-target=announcement]", text: "PDF本文 2 / 2 ページ", visible: :all
    page_input = find("input[aria-label='ページ番号へ移動']:not(:disabled)")
    assert_equal "2", page_input.value
    assert_selector "button[data-action='pdf#prev'][aria-disabled='false']"
    assert_selector "button[data-action='pdf#next'][aria-disabled='true']:focus"
  end

  test "announces a load failure and exposes retry and download actions" do
    visit material_path(@material)
    page.execute_script <<~JS
      document.querySelector('[data-controller="pdf"]')
        .setAttribute('data-pdf-url-value', '/materials/missing/pdf')
    JS
    click_on "status.pdf"

    assert_selector "dialog[aria-busy='false'] [data-pdf-target=status]",
      text: "プレビューを読み込めませんでした", visible: :all
    assert_button "再試行", visible: true
    assert_link "PDFをダウンロード", href: rails_blob_path(@material.file)
    assert_selector "button[data-action='pdf#prev'][aria-disabled='true']"
    assert_selector "button[data-action='pdf#next'][aria-disabled='true']"
    assert_selector "input[aria-label='ページ番号へ移動'][disabled]"
  end

  private

  def two_page_pdf
    objects = [
      "1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n",
      "2 0 obj\n<< /Type /Pages /Kids [3 0 R 4 0 R] /Count 2 >>\nendobj\n",
      "3 0 obj\n<< /Type /Page /Parent 2 0 R /MediaBox [0 0 600 800] >>\nendobj\n",
      "4 0 obj\n<< /Type /Page /Parent 2 0 R /MediaBox [0 0 600 800] >>\nendobj\n"
    ]
    pdf = +"%PDF-1.4\n"
    offsets = objects.map { |object| pdf.bytesize.tap { pdf << object } }
    xref = pdf.bytesize
    pdf << "xref\n0 5\n0000000000 65535 f \n"
    offsets.each { |offset| pdf << format("%010d 00000 n \n", offset) }
    pdf << "trailer\n<< /Size 5 /Root 1 0 R >>\nstartxref\n#{xref}\n%%EOF\n"
  end
end
