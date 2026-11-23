require "application_system_test_case"

class PdfViewerDirectionTest < ApplicationSystemTestCase
  setup do
    @user = create(:user)
    @material = Material.new(user: @user, title: "綴じ方向PDF")
    @material.file.attach(
      io: StringIO.new(one_page_pdf),
      filename: "direction.pdf",
      content_type: "application/pdf"
    )
    @material.save!
  end

  test "shows binding direction as toggle state and provides touch-friendly control help" do
    sign_in_through_ui(@user)
    visit material_path(@material)
    click_on "direction.pdf"
    assert_selector "dialog[open] .pdf-viewer__stage canvas", wait: 10

    direction = find("button[data-action='pdf#toggleDirection']")
    assert_equal "false", direction["aria-pressed"]
    assert_equal "右開きで読む", direction["aria-label"]
    assert_text "左開き"

    direction.click

    assert_equal "true", direction["aria-pressed"]
    assert_equal "右開きで読む", direction["aria-label"]
    assert_text "右開き"

    find("details.pdf-viewer__help summary").click
    within "details.pdf-viewer__help" do
      assert_text "前のページ / 次のページ"
      assert_text "全体を表示（フィット）"
      assert_text "閉じる"
      assert_text "ドラッグして移動"
      assert_text "綴じ方向に追従"
      assert_text "PageUp / PageDown"
      assert_text "Ctrl / ⌘ + ホイール"
      assert_text "ダブルクリック"
      assert_text "等倍"
    end
  end

  test "keeps the visible binding direction clear at 375px width" do
    emulate_touch_viewport(375, 667)
    sign_in_through_ui(@user)
    visit material_path(@material)
    click_on "direction.pdf"
    assert_selector "dialog[open] .pdf-viewer__stage canvas", wait: 10

    direction = find("button[data-action='pdf#toggleDirection']")
    nav = find("[data-pdf-target='nav']")
    direction_rect = element_rect(direction)
    nav_rect = element_rect(nav)

    assert_equal "左開き", direction.find("[data-pdf-target='dirLabel']").text
    assert_operator direction.native.property("scrollWidth"), :<=, direction.native.property("clientWidth")
    assert_operator direction_rect.fetch("right"), :<=, nav_rect.fetch("x")
    assert_operator direction_rect.fetch("x"), :>=, 0
    assert_operator direction_rect.fetch("right"), :<=, page.evaluate_script("window.innerWidth")
  end

  private

  def emulate_touch_viewport(width, height)
    page.driver.browser.execute_cdp(
      "Emulation.setDeviceMetricsOverride",
      width: width, height: height, deviceScaleFactor: 1, mobile: true
    )
    page.driver.browser.execute_cdp(
      "Emulation.setTouchEmulationEnabled",
      enabled: true, maxTouchPoints: 5
    )
  end

  def element_rect(element)
    page.evaluate_script(<<~JS, element)
      (() => {
        const rect = arguments[0].getBoundingClientRect()
        return { x: rect.x, right: rect.right }
      })()
    JS
  end

  def one_page_pdf
    objects = [
      "1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n",
      "2 0 obj\n<< /Type /Pages /Kids [3 0 R] /Count 1 >>\nendobj\n",
      "3 0 obj\n<< /Type /Page /Parent 2 0 R /MediaBox [0 0 600 800] >>\nendobj\n"
    ]
    pdf = +"%PDF-1.4\n"
    offsets = objects.map { |object| pdf.bytesize.tap { pdf << object } }
    xref = pdf.bytesize
    pdf << "xref\n0 4\n0000000000 65535 f \n"
    offsets.each { |offset| pdf << format("%010d 00000 n \n", offset) }
    pdf << "trailer\n<< /Size 4 /Root 1 0 R >>\nstartxref\n#{xref}\n%%EOF\n"
  end
end
