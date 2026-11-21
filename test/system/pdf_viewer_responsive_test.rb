require "application_system_test_case"

class PdfViewerResponsiveTest < ApplicationSystemTestCase
  setup do
    @user = create(:user)
    @material = Material.new(user: @user, title: "狭幅PDF")
    @material.file.attach(
      io: StringIO.new(one_page_pdf),
      filename: "responsive.pdf",
      content_type: "application/pdf"
    )
    @material.save!
  end

  test "keeps touch-sized primary controls in view at narrow width and after rotation" do
    emulate_touch_viewport(320, 568)
    sign_in_through_ui(@user)
    visit material_path(@material)
    click_on "responsive.pdf"
    assert_selector "dialog[open] .pdf-viewer__stage canvas"

    primary_controls.each do |selector|
      rect = element_rect(selector)
      assert_operator rect.fetch("width"), :>=, 44, selector
      assert_operator rect.fetch("height"), :>=, 44, selector
    end

    page.execute_script("document.documentElement.style.fontSize = '32px'")
    page.execute_script("window.dispatchEvent(new Event('resize'))")

    primary_controls.each do |selector|
      rect = element_rect(selector)
      assert_inside_viewport rect, selector
    end
    assert_inside_viewport element_rect("dialog.lightbox--pdf"), "dialog"
    assert_no_selector ".pdf-viewer__resizer", visible: true

    emulate_touch_viewport(390, 844)
    page.execute_script("window.dispatchEvent(new Event('resize'))")
    primary_controls.each { |selector| assert_inside_viewport element_rect(selector), "390px #{selector}" }
    assert_inside_viewport element_rect("dialog.lightbox--pdf"), "390px dialog"

    emulate_touch_viewport(568, 320)
    page.execute_script("window.dispatchEvent(new Event('resize'))")

    assert_inside_viewport element_rect("dialog.lightbox--pdf"), "rotated dialog"
    assert_inside_viewport element_rect(".pdf-viewer__stage"), "rotated stage"
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

  def primary_controls
    [
      "button[data-action='pdf#prev']",
      "button[data-action='pdf#next']",
      "button[data-action='pdf#zoomOut']",
      "button[data-action='pdf#zoomIn']",
      "button[data-action='pdf#fit']",
      "button[data-action='pdf#close']"
    ]
  end

  def element_rect(selector)
    page.evaluate_script(<<~JS)
      (() => {
        const rect = document.querySelector(#{selector.to_json}).getBoundingClientRect()
        return { x: rect.x, y: rect.y, right: rect.right, bottom: rect.bottom,
                 width: rect.width, height: rect.height }
      })()
    JS
  end

  def assert_inside_viewport(rect, label)
    assert_operator rect.fetch("x"), :>=, 0, label
    assert_operator rect.fetch("y"), :>=, 0, label
    assert_operator rect.fetch("right"), :<=, page.evaluate_script("window.innerWidth"), label
    assert_operator rect.fetch("bottom"), :<=, page.evaluate_script("window.innerHeight"), label
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
