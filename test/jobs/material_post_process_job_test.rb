require "test_helper"

class MaterialPostProcessJobTest < ActiveJob::TestCase
  # minitest 6 に Object#stub が無いので、モジュールメソッドを一時的に差し替える。
  def stub_singleton(mod, method_name, value)
    original = mod.method(method_name)
    mod.define_singleton_method(method_name) { |*| value }
    yield
  ensure
    mod.define_singleton_method(method_name, original)
  end

  def user
    @user ||= User.create!(email_address: "job@example.com", name: "Job", provider: "discord", uid: "job-u")
  end

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

  test "perform is a safe no-op when no file is attached and nothing to autofill" do
    link = Material.create!(user: user, url: "https://example.com/x", title: "リンク", published_year: 2020)
    assert_nothing_raised { MaterialPostProcessJob.perform_now(link) }
  end

  test "perform autofills a blank link title from og:title" do
    # title 未記入だと ensure_title が url を入れる＝後追いの上書き対象。
    link = Material.create!(user: user, url: "https://example.com/page")
    assert_equal link.url, link.title

    stub_singleton(VideoMetadata, :call, nil) do
      stub_singleton(OgTitleFetcher, :call, "ページ題名") do
        MaterialPostProcessJob.perform_now(link)
      end
    end
    assert_equal "ページ題名", link.reload.title
  end

  test "perform autofills a blank link title and date from the video api" do
    link = Material.create!(user: user, url: "https://www.youtube.com/watch?v=oxCt6HYg4bo")

    stub_singleton(VideoMetadata, :call, { title: "動画タイトル", published_on: Date.new(2012, 10, 13) }) do
      MaterialPostProcessJob.perform_now(link)
    end
    link.reload
    assert_equal "動画タイトル", link.title
    assert_equal Time.zone.local(2012, 10, 13), link.published_at
    assert_equal "day", link.published_precision
  end

  test "perform keeps a user-entered title and published date" do
    link = Material.create!(user: user, url: "https://vimeo.com/838983799", title: "手動", published_year: 1991)

    stub_singleton(VideoMetadata, :call, { title: "上書きしない", published_on: Date.new(2012, 10, 13) }) do
      MaterialPostProcessJob.perform_now(link)
    end
    link.reload
    assert_equal "手動", link.title
    assert_equal 1991, link.published_at.year
    assert_equal "year", link.published_precision
  end

  test "perform leaves the url as title when nothing can be fetched" do
    link = Material.create!(user: user, url: "https://example.com/no-title")

    stub_singleton(VideoMetadata, :call, nil) do
      stub_singleton(OgTitleFetcher, :call, nil) do
        MaterialPostProcessJob.perform_now(link)
      end
    end
    assert_equal "https://example.com/no-title", link.reload.title
  end
end
