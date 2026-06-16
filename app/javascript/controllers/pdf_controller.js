import { Controller } from "@hotwired/stimulus"

// PDF.js によるページ単位ビューア。ファイル名クリックで <dialog> オーバーレイとして開き、初回オープン時にだけ
// 本体を CDN から動的 import する（開かなければ一切ダウンロードされない）。
// 配信は同一オリジンの Materials::PdfController（Content-Length + Accept-Ranges + identity）なので、
// 大きな PDF でも表示ページに必要なチャンクだけ Range 取得して描画する。
// 表示はページ本来のアスペクト比を厳密に維持し、既定はビューポートにフィット。
// 操作: 前後ボタン／番号入力ジャンプ／←→キー（綴じ方向追従）／拡大縮小・等倍・フィット／
//       拡大時はドラッグでパン・Ctrl+ホイールでズーム・ダブルクリックでフィット⇄等倍。リサイズで再フィット。
export default class extends Controller {
  static targets = ["dialog", "canvas", "pageInput", "pageTotal", "status", "pct", "stage", "nav", "dir"]
  static values = { url: String }

  MIN_SCALE = 0.15
  MAX_SCALE = 4
  MAX_BITMAP = 4096 // 拡大時のメモリ暴走を防ぐビットマップ最大辺(px)

  connect() {
    this.rtl = false // 既定は左開き（洋書）。右開き（和書・縦書き）はビューア内トグルで切替（セッション内のみ）。
    this.fitted = true // 現在の倍率がフィット由来か（リサイズ再フィットの対象判定）。
    this.applyDirection()
    this.onResize = () => this.handleResize()
    window.addEventListener("resize", this.onResize)
    this.setupStageInteractions()
  }

  disconnect() {
    window.removeEventListener("resize", this.onResize)
    this.renderTask?.cancel()
    this.doc?.destroy()
    this.doc = null
  }

  async open(event) {
    event.preventDefault()
    this.dialogTarget.showModal()
    await this.load()
  }

  // 綴じ方向トグル。右開きでは「次へ」が左に来るようナビを反転し、矢印キーの向きも入れ替える。
  toggleDirection() {
    this.rtl = !this.rtl
    this.applyDirection()
  }

  applyDirection() {
    this.navTarget.classList.toggle("pdf-viewer__nav--rtl", this.rtl)
    this.dirTarget.textContent = this.rtl ? "右開き" : "左開き"
  }

  // ←→ キーでのページ送り。左開きは →=次, 右開きは ←=次（読み進み方向に一致）。
  // 番号入力欄にフォーカス中はキーを横取りしない（入力のカーソル移動を優先）。
  key(event) {
    if (event.key !== "ArrowLeft" && event.key !== "ArrowRight") return
    if (event.target instanceof HTMLInputElement) return
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

  // 拡大時のドラッグでパン・Ctrl+ホイールでズーム・ダブルクリックでフィット⇄等倍。
  setupStageInteractions() {
    const stage = this.stageTarget
    let dragging = false
    let startX = 0, startY = 0, startLeft = 0, startTop = 0

    stage.addEventListener("pointerdown", (e) => {
      if (e.button !== 0 || !this.scrollable()) return
      dragging = true
      startX = e.clientX; startY = e.clientY
      startLeft = stage.scrollLeft; startTop = stage.scrollTop
      stage.classList.add("is-panning")
      stage.setPointerCapture(e.pointerId)
    })
    stage.addEventListener("pointermove", (e) => {
      if (!dragging) return
      stage.scrollLeft = startLeft - (e.clientX - startX)
      stage.scrollTop = startTop - (e.clientY - startY)
    })
    const endDrag = (e) => {
      if (!dragging) return
      dragging = false
      stage.classList.remove("is-panning")
      try { stage.releasePointerCapture(e.pointerId) } catch { /* already released */ }
    }
    stage.addEventListener("pointerup", endDrag)
    stage.addEventListener("pointercancel", endDrag)

    stage.addEventListener("wheel", (e) => {
      if (!(e.ctrlKey || e.metaKey)) return // 通常スクロールは温存、Ctrl/⌘+ホイールだけズーム
      e.preventDefault()
      e.deltaY < 0 ? this.zoomIn() : this.zoomOut()
    }, { passive: false })

    stage.addEventListener("dblclick", () => this.toggleZoom())
  }

  scrollable() {
    const s = this.stageTarget
    return s.scrollWidth > s.clientWidth + 1 || s.scrollHeight > s.clientHeight + 1
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
    const w = this.baseViewport.width * fs + 2 // +2 は canvas の枠線分
    this.stageTarget.style.width = `${w}px`
    this.stageTarget.style.height = `${this.baseViewport.height * fs + 2}px`
    // dialog がページをぎりぎり囲むよう、viewer 幅をステージ幅＋左右パディング(0.8rem×2)に揃える
    // （box-sizing: border-box 前提）。ツールバーはこの幅内で折り返し、dialog は中身に追従する。
    const viewer = this.stageTarget.closest(".pdf-viewer")
    if (viewer) viewer.style.maxWidth = `calc(${w}px + 1.6rem)`
  }

  async render() {
    if (!this.doc) return
    const token = (this.token = (this.token || 0) + 1)
    this.renderTask?.cancel()

    const page = await this.doc.getPage(this.pageNum)
    if (token !== this.token) return // 後続の操作に追い越されたら破棄

    this.baseViewport = page.getViewport({ scale: 1 })
    const firstFit = this.scale == null
    if (firstFit) { this.scale = this.fitScaleFor(this.baseViewport); this.fitted = true }
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
    this.pageInputTarget.value = this.pageNum
    this.pageInputTarget.max = this.doc.numPages
    this.pageTotalTarget.textContent = this.doc.numPages
    this.pctTarget.textContent = `${Math.round(this.scale * 100)}%`
    this.stageTarget.classList.toggle("is-pannable", this.scrollable())
  }

  // 番号入力からそのページへジャンプ（範囲外はクランプ）。
  jump() {
    if (!this.doc) return
    let n = parseInt(this.pageInputTarget.value, 10)
    if (Number.isNaN(n)) { this.pageInputTarget.value = this.pageNum; return }
    n = Math.min(Math.max(n, 1), this.doc.numPages)
    if (n === this.pageNum) { this.pageInputTarget.value = n; return }
    this.pageNum = n
    this.render()
  }

  prev() {
    if (this.doc && this.pageNum > 1) { this.pageNum--; this.render() }
  }

  next() {
    if (this.doc && this.pageNum < this.doc.numPages) { this.pageNum++; this.render() }
  }

  zoomIn() { this.scale = (this.scale ?? 1) * 1.25; this.fitted = false; this.render() }
  zoomOut() { this.scale = (this.scale ?? 1) / 1.25; this.fitted = false; this.render() }
  actualSize() { this.scale = 1; this.fitted = false; this.render() } // 等倍 (1pt = 1px)

  fit() {
    if (!this.baseViewport) return
    this.scale = this.fitScaleFor(this.baseViewport)
    this.fitted = true
    this.sizeStage()
    this.render()
  }

  // ダブルクリック: ほぼフィットなら等倍へ、それ以外はフィットへ。
  toggleZoom() {
    if (!this.baseViewport) return
    const fs = this.fitScaleFor(this.baseViewport)
    if (Math.abs(this.scale - fs) < 0.01) { this.scale = 1; this.fitted = false } else { this.scale = fs; this.fitted = true }
    this.render()
  }

  // ウィンドウのリサイズ/回転時、フィット表示中ならフィット倍率を取り直して追従する。
  handleResize() {
    if (!this.doc || !this.dialogTarget.open || !this.fitted || !this.baseViewport) return
    this.scale = this.fitScaleFor(this.baseViewport)
    this.sizeStage()
    this.render()
  }
}
