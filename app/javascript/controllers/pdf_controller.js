import { Controller } from "@hotwired/stimulus"

// PDF.js によるページ単位ビューア。ファイル名クリックで <dialog> オーバーレイとして開き、初回オープン時にだけ
// 本体を CDN から動的 import する（開かなければ一切ダウンロードされない）。
// 配信は同一オリジンの Materials::PdfController（Content-Length + Accept-Ranges + identity）なので、
// 大きな PDF でも表示ページに必要なチャンクだけ Range 取得して描画する。
// 表示はページ本来のアスペクト比を厳密に維持し、既定はビューポートにフィット。拡大/縮小/等倍/フィット操作つき。
export default class extends Controller {
  static targets = ["dialog", "canvas", "page", "status", "pct", "stage", "nav", "dir"]
  static values = { url: String }

  MIN_SCALE = 0.15
  MAX_SCALE = 4
  MAX_BITMAP = 4096 // 拡大時のメモリ暴走を防ぐビットマップ最大辺(px)

  connect() {
    this.rtl = false // 既定は左開き（洋書）。右開き（和書・縦書き）はビューア内トグルで切替（セッション内のみ）。
    this.applyDirection()
  }

  async open(event) {
    event.preventDefault()
    this.dialogTarget.showModal()
    await this.load()
  }

  // 綴じ方向トグル。右開きでは「次へ」が左に来るようナビを反転し、矢印キーの向きも入れ替える。
  // ページ送りの番号（pageNum++）は方向に依らず同じ。保存はしない（セッション内のみ）。
  toggleDirection() {
    this.rtl = !this.rtl
    this.applyDirection()
  }

  applyDirection() {
    this.navTarget.classList.toggle("pdf-viewer__nav--rtl", this.rtl)
    this.dirTarget.textContent = this.rtl ? "右開き" : "左開き"
  }

  // 矢印キーでのページ送り。左開きは →=次, 右開きは ←=次（読み進み方向に一致）。
  key(event) {
    if (event.key !== "ArrowLeft" && event.key !== "ArrowRight") return
    event.preventDefault()
    const advance = this.rtl ? event.key === "ArrowLeft" : event.key === "ArrowRight"
    advance ? this.next() : this.prev()
  }

  close() {
    this.dialogTarget.close()
  }

  // dialog 自身（=背景余白）がクリックされたときだけ閉じる
  backdropClose(event) {
    if (event.target === this.dialogTarget) this.dialogTarget.close()
  }

  async load() {
    if (this.doc) return
    this.pageNum = 1
    this.scale = null // null = 初回描画でフィット倍率を算出
    this.statusTarget.textContent = "読み込み中…"
    try {
      const pdfjs = await import("pdfjs-dist")
      pdfjs.GlobalWorkerOptions.workerSrc =
        "https://cdn.jsdelivr.net/npm/pdfjs-dist@4.10.38/build/pdf.worker.min.mjs"
      // disableAutoFetch/Stream: 全体の先読みをやめ、表示に必要な範囲だけ Range 取得する
      this.doc = await pdfjs.getDocument({
        url: this.urlValue, disableAutoFetch: true, disableStream: true
      }).promise
      this.statusTarget.textContent = ""
      await this.render()
    } catch {
      this.statusTarget.textContent = "プレビューを読み込めませんでした（ダウンロードしてご覧ください）"
    }
  }

  disconnect() {
    this.renderTask?.cancel()
    this.doc?.destroy()
    this.doc = null
  }

  // ページ全体がビューポート（おおよそ 90vw × 78vh）に収まる倍率。
  fitScaleFor(viewport1) {
    const maxW = window.innerWidth * 0.90
    const maxH = window.innerHeight * 0.78
    return Math.min(maxW / viewport1.width, maxH / viewport1.height)
  }

  // ステージ枠を「フィット時のページ表示寸法」に固定する。以後ズームしても枠＝ツールバーは動かず、
  // canvas だけが枠内で拡大縮小・スクロールする。+2px は canvas の枠線分。
  sizeStage() {
    const fs = this.fitScaleFor(this.baseViewport)
    this.stageTarget.style.width = `${this.baseViewport.width * fs + 2}px`
    this.stageTarget.style.height = `${this.baseViewport.height * fs + 2}px`
  }

  async render() {
    if (!this.doc) return
    const token = (this.token = (this.token || 0) + 1)
    this.renderTask?.cancel()

    const page = await this.doc.getPage(this.pageNum)
    if (token !== this.token) return // 後続の操作に追い越されたら破棄

    this.baseViewport = page.getViewport({ scale: 1 })
    const firstFit = this.scale == null
    if (firstFit) this.scale = this.fitScaleFor(this.baseViewport)
    this.scale = Math.min(Math.max(this.scale, this.MIN_SCALE), this.MAX_SCALE)
    if (firstFit) this.sizeStage() // 初回にステージ枠（=フィット時のページ寸法）を確定して固定する

    // 表示サイズは this.scale 基準でアスペクト比を厳密に維持（画面の縦横比に依存しない）。
    const display = page.getViewport({ scale: this.scale })
    // 描画ビットマップは devicePixelRatio で鮮明にしつつ、最大辺を MAX_BITMAP に制限する。
    const dpr = window.devicePixelRatio || 1
    let renderScale = this.scale * dpr
    const maxDim = Math.max(display.width, display.height) * dpr
    if (maxDim > this.MAX_BITMAP) renderScale *= this.MAX_BITMAP / maxDim
    const bitmap = page.getViewport({ scale: renderScale })

    const c = this.canvasTarget
    c.width = bitmap.width
    c.height = bitmap.height
    c.style.width = `${display.width}px`
    c.style.height = `${display.height}px`

    this.renderTask = page.render({ canvasContext: c.getContext("2d"), viewport: bitmap })
    try {
      await this.renderTask.promise
    } catch (e) {
      if (e?.name === "RenderingCancelledException") return
      throw e
    }
    if (token !== this.token) return
    this.pageTarget.textContent = `${this.pageNum} / ${this.doc.numPages}`
    this.pctTarget.textContent = `${Math.round(this.scale * 100)}%`
  }

  prev() {
    if (this.doc && this.pageNum > 1) { this.pageNum--; this.render() }
  }

  next() {
    if (this.doc && this.pageNum < this.doc.numPages) { this.pageNum++; this.render() }
  }

  zoomIn() { this.scale = (this.scale ?? 1) * 1.25; this.render() }
  zoomOut() { this.scale = (this.scale ?? 1) / 1.25; this.render() }
  actualSize() { this.scale = 1; this.render() }            // 等倍 (1pt = 1px)
  fit() {
    if (!this.baseViewport) return
    this.scale = this.fitScaleFor(this.baseViewport)
    this.sizeStage()
    this.render()
  }
}
