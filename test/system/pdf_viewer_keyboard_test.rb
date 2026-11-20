require "application_system_test_case"

class PdfViewerKeyboardTest < ApplicationSystemTestCase
  setup do
    @user = create(:user)
    @material = Material.new(user: @user, title: "キーボード操作PDF")
    @material.file.attach(
      io: StringIO.new(two_page_pdf),
      filename: "keyboard-pan.pdf",
      content_type: "application/pdf"
    )
    @material.save!
  end

  test "arrow keys pan a zoomed page without changing pages" do
    sign_in_through_ui(@user)
    visit material_path(@material)
    click_on "keyboard-pan.pdf"

    assert_selector "dialog[open] .pdf-viewer__stage canvas"
    stage = find(".pdf-viewer__stage")
    assert_equal "0", stage[:tabindex]
    assert_includes stage[:"aria-label"], "矢印キー"

    8.times { click_button "拡大" }
    assert_operator page.evaluate_script("arguments[0].scrollWidth", stage), :>,
      page.evaluate_script("arguments[0].clientWidth", stage)
    assert_operator page.evaluate_script("arguments[0].scrollHeight", stage), :>,
      page.evaluate_script("arguments[0].clientHeight", stage)

    stage.send_keys(:arrow_right)
    stage.send_keys(:arrow_down)

    assert_operator page.evaluate_script("arguments[0].scrollLeft", stage), :>, 0
    assert_operator page.evaluate_script("arguments[0].scrollTop", stage), :>, 0
    assert_equal "1", find(".pdf-viewer__pageinput").value
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
