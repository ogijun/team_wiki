import { Controller } from "@hotwired/stimulus"

// PDF.js によるページ単位ビューア。本体は importmap 経由で CDN から動的 import するので、
// PDF の無いページでは一切ダウンロードされない。配信は ActiveStorage のプロキシ URL
// （同一オリジン・Range 対応）なので、大きな PDF でも必要なチャンクだけ取得して描画できる。
export default class extends Controller {
  static targets = ["canvas", "page", "status"]
  static values = { url: String }

  async connect() {
    this.pageNum = 1
    try {
      const pdfjs = await import("pdfjs-dist")
      pdfjs.GlobalWorkerOptions.workerSrc =
        "https://cdn.jsdelivr.net/npm/pdfjs-dist@4.10.38/build/pdf.worker.min.mjs"
      // disableAutoFetch/Stream: 全体の先読みをやめ、表示に必要な範囲だけ Range 取得する
      this.doc = await pdfjs.getDocument({
        url: this.urlValue, disableAutoFetch: true, disableStream: true
      }).promise
      await this.render()
    } catch {
      this.statusTarget.textContent = "プレビューを読み込めませんでした（ダウンロードしてご覧ください）"
    }
  }

  disconnect() {
    this.doc?.destroy()
    this.doc = null
  }

  async render() {
    const page = await this.doc.getPage(this.pageNum)
    const scale = this.canvasTarget.parentElement.clientWidth / page.getViewport({ scale: 1 }).width
    const viewport = page.getViewport({ scale: scale * window.devicePixelRatio })
    this.canvasTarget.width = viewport.width
    this.canvasTarget.height = viewport.height
    this.canvasTarget.style.width = `${viewport.width / window.devicePixelRatio}px`
    await page.render({ canvasContext: this.canvasTarget.getContext("2d"), viewport }).promise
    this.pageTarget.textContent = `${this.pageNum} / ${this.doc.numPages}`
  }

  prev() {
    if (this.pageNum > 1) { this.pageNum--; this.render() }
  }

  next() {
    if (this.pageNum < this.doc.numPages) { this.pageNum++; this.render() }
  }
}
