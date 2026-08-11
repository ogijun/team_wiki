import { Controller } from "@hotwired/stimulus"

// PDF.js によるページ単位ビューア。ファイル名クリックで <dialog> オーバーレイとして開き、初回オープン時にだけ
// 本体を CDN から動的 import する（開かなければ一切ダウンロードされない）。
// 配信は同一オリジンの Materials::PdfController（Content-Length + Accept-Ranges + identity）なので、
// 大きな PDF でも表示ページに必要なチャンクだけ Range 取得して描画する。
// 表示はページ本来のアスペクト比を厳密に維持し、既定はビューポートにフィット。
// 操作: 前後ボタン／番号入力ジャンプ／←→キー（綴じ方向追従）／拡大縮小・等倍・フィット／
//       拡大時はドラッグでパン・Ctrl+ホイールでズーム・ダブルクリックでフィット⇄等倍。リサイズで再フィット。
export default class extends Controller {
  static targets = ["dialog", "pageInput", "pageTotal", "status", "pct", "stage", "nav", "dir"]
  static values = { url: String }

  MIN_SCALE = 0.15
  MAX_SCALE = 4
  MAX_BITMAP = 4096 // 拡大時のメモリ暴走を防ぐビットマップ最大辺(px)

  connect() {
    this.rtl = false // 既定は左開き（洋書）。右開き（和書・縦書き）はビューア内トグルで切替（セッション内のみ）。
    this.fitted = true // 現在の倍率がフィット由来か（リサイズ再フィットの対象判定）。
    this.userResized = false // 隅のハンドルで手動リサイズしたか（以後 window リサイズで自動フィットしない）。
    this._lastStageSize = { w: 0, h: 0 } // sizeStage 由来の変更を ResizeObserver で無視するための記録。
    this.offset = { x: 0, y: 0 } // ツールバーをつかんで動かした移動量。
    // pageNum ごとに canvas と描画タスクを持つ。canvas は常に現在ページ±1だけ保持し、
    // ページ送りでは描画済み canvas を切り替えるだけにする。
    this.canvasCache = new Map()
    this.cacheGeneration = 0
    this.renderToken = 0
    // Turbo の復元では前回の canvas が生きた DOM のまま残る。ここで空にして、
    // この接続のキャッシュだけがステージを所有するようにする。
    this.stageTarget.replaceChildren()
    this.applyDirection()
    this.onResize = () => this.handleResize()
    window.addEventListener("resize", this.onResize)
    this.setupStageInteractions()
    this.setupDrag()
    this.setupResizer()
  }

  disconnect() {
    window.removeEventListener("resize", this.onResize)
    this.stageResizeObserver?.disconnect()
    this.clearCanvasCache()
    this.doc?.destroy()
    this.doc = null
  }

  async open(event) {
    event.preventDefault()
    this.resetPosition() // 開くたびに中央へ（移動の持ち越しで行方不明にならないように）。
    this.dialogTarget.showModal()
    await this.load()
  }

  resetPosition() {
    this.offset = { x: 0, y: 0 }
    this.dialogTarget.style.transform = ""
  }

  // 綴じ方向トグル。右開きでは「次へ」が左に来るようナビを反転し、矢印キーの向きも入れ替える。
  toggleDirection() {
    this.rtl = !this.rtl
    this.applyDirection()
  }

  applyDirection() {
    this.navTarget.classList.toggle("pdf-viewer__nav--rtl", this.rtl)
    // アイコンボタン化したので、現在の綴じ方向は title/aria-label と本(アイコン)の左右反転で示す。
    const label = this.rtl ? "綴じ方向: 右開き（クリックで左開き）" : "綴じ方向: 左開き（クリックで右開き）"
    this.dirTarget.title = label
    this.dirTarget.setAttribute("aria-label", label)
    this.dirTarget.classList.toggle("is-rtl", this.rtl)
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

    // 隅のハンドル（CSS resize）でステージをリサイズ。フィット中はページを新サイズへ再フィット、
    // それ以外の倍率なら枠だけ変える（倍率は維持してスクロール）。
    this.stageResizeObserver = new ResizeObserver(() => this.onStageResize())
    this.stageResizeObserver.observe(stage)
  }

  // ツールバーをつかんでビューアを移動（操作子の上では動かさない）。<dialog> は中央配置のまま
  // transform で平行移動させる。
  setupDrag() {
    const bar = this.element.querySelector(".pdf-viewer__bar")
    if (!bar) return
    let dragging = false
    let startX = 0, startY = 0, baseX = 0, baseY = 0
    bar.addEventListener("pointerdown", (e) => {
      if (e.button !== 0 || e.target.closest("button, input, a, .pdf-viewer__pct")) return
      dragging = true
      startX = e.clientX; startY = e.clientY
      baseX = this.offset.x; baseY = this.offset.y
      bar.classList.add("is-dragging")
      bar.setPointerCapture(e.pointerId)
    })
    bar.addEventListener("pointermove", (e) => {
      if (!dragging) return
      this.offset = { x: baseX + (e.clientX - startX), y: baseY + (e.clientY - startY) }
      this.dialogTarget.style.transform = `translate(${this.offset.x}px, ${this.offset.y}px)`
    })
    const end = (e) => {
      if (!dragging) return
      dragging = false
      bar.classList.remove("is-dragging")
      try { bar.releasePointerCapture(e.pointerId) } catch { /* already released */ }
    }
    bar.addEventListener("pointerup", end)
    bar.addEventListener("pointercancel", end)
  }

  // 右下のグリップでステージをリサイズ。実際の寸法変更は ResizeObserver(onStageResize) が拾って
  // 再フィット/枠変更する（native の resize ハンドルは視認しづらいので自前グリップで代替）。
  setupResizer() {
    const handle = this.element.querySelector(".pdf-viewer__resizer")
    if (!handle) return
    let resizing = false
    let sx = 0, sy = 0, sw = 0, sh = 0
    handle.addEventListener("pointerdown", (e) => {
      e.preventDefault()
      resizing = true
      sx = e.clientX; sy = e.clientY
      sw = this.stageTarget.clientWidth; sh = this.stageTarget.clientHeight
      handle.setPointerCapture(e.pointerId)
    })
    handle.addEventListener("pointermove", (e) => {
      if (!resizing) return
      this.stageTarget.style.width = `${Math.max(220, sw + (e.clientX - sx))}px`
      this.stageTarget.style.height = `${Math.max(160, sh + (e.clientY - sy))}px`
    })
    const end = (e) => {
      if (!resizing) return
      resizing = false
      try { handle.releasePointerCapture(e.pointerId) } catch { /* already released */ }
    }
    handle.addEventListener("pointerup", end)
    handle.addEventListener("pointercancel", end)
  }

  // 隅のハンドルでステージが変わったときの処理（自前の sizeStage 由来はスキップ）。
  onStageResize() {
    if (!this.doc || !this.baseViewport) return
    const w = this.stageTarget.clientWidth
    const h = this.stageTarget.clientHeight
    if (Math.abs(w - this._lastStageSize.w) < 2 && Math.abs(h - this._lastStageSize.h) < 2) return
    this._lastStageSize = { w, h }
    this.userResized = true
    this.syncViewerWidth()
    if (this.fitted) {
      this.scale = this.fitScaleToStage()
      this.render({ invalidateCache: true })
    } else {
      this.stageTarget.classList.toggle("is-pannable", this.scrollable())
    }
  }

  // ステージ内側にページ全体が収まる倍率（手動リサイズ時の再フィット用）。−2 は canvas の枠線分。
  fitScaleToStage() {
    const availW = this.stageTarget.clientWidth - 2
    const availH = this.stageTarget.clientHeight - 2
    return Math.min(availW / this.baseViewport.width, availH / this.baseViewport.height)
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
    this.syncViewerWidth()
    this.rememberStageSize() // ResizeObserver が「自前の変更」を手動リサイズと誤認しないよう記録
  }

  // dialog がページをぎりぎり囲むよう、viewer 幅をステージ幅＋左右パディング(0.8rem×2)に揃える
  // （box-sizing: border-box 前提）。ツールバーはこの幅内で折り返し、dialog は中身に追従する。
  syncViewerWidth() {
    const viewer = this.stageTarget.closest(".pdf-viewer")
    if (viewer) viewer.style.maxWidth = `calc(${this.stageTarget.clientWidth}px + 1.6rem)`
  }

  rememberStageSize() {
    this._lastStageSize = { w: this.stageTarget.clientWidth, h: this.stageTarget.clientHeight }
  }

  // 現在ページを表示し、描画済みなら canvas の表示切替だけで完了する。倍率変更時は
  // 世代を切り替えて全キャッシュを無効化し、現在ページを描いてから隣接を追う。
  async render({ invalidateCache = false } = {}) {
    if (!this.doc) return
    const token = ++this.renderToken
    if (invalidateCache) this.clearCanvasCache()
    const generation = this.cacheGeneration
    this.evictDistantCanvases()

    try {
      const entry = await this.renderPage(this.pageNum, generation)
      if (!entry || token !== this.renderToken || generation !== this.cacheGeneration) return
      this.showCanvas(entry)
      this.prefetchAdjacentPages(generation)
    } catch (e) {
      if (e?.name === "RenderingCancelledException") return
      this.statusTarget.textContent = "ページを描画できませんでした"
    }
  }

  // pageNum 単位で PDF.js の RenderTask を管理する。範囲外へ出たページだけをキャンセルできるため、
  // 3 枚の並行描画でも現在ページのタスクを取り違えない。
  renderPage(pageNum, generation) {
    const cached = this.canvasCache.get(pageNum)
    if (cached?.generation === generation) return cached.promise

    const canvas = document.createElement("canvas")
    canvas.hidden = true
    this.stageTarget.append(canvas)
    const entry = { pageNum, generation, canvas, ready: false, task: null }
    entry.promise = this.drawPage(entry)
    this.canvasCache.set(pageNum, entry)
    return entry.promise
  }

  async drawPage(entry) {
    const page = await this.doc.getPage(entry.pageNum)
    if (!this.isCurrentCacheEntry(entry)) return null

    entry.baseViewport = page.getViewport({ scale: 1 })
    if (this.scale == null) {
      this.baseViewport = entry.baseViewport
      this.scale = this.fitScaleFor(this.baseViewport)
      this.fitted = true
      this.sizeStage()
    }
    this.scale = Math.min(Math.max(this.scale, this.MIN_SCALE), this.MAX_SCALE)

    // 各ページ自身の viewport で描く。ページごとに寸法が違う PDF でもキャッシュを共有しない。
    const display = page.getViewport({ scale: this.scale })
    const dpr = window.devicePixelRatio || 1
    let renderScale = this.scale * dpr
    const maxDim = Math.max(display.width, display.height) * dpr
    if (maxDim > this.MAX_BITMAP) renderScale *= this.MAX_BITMAP / maxDim
    const bitmap = page.getViewport({ scale: renderScale })
    const canvas = entry.canvas
    canvas.width = bitmap.width
    canvas.height = bitmap.height
    canvas.style.width = `${display.width}px`
    canvas.style.height = `${display.height}px`

    entry.task = page.render({ canvasContext: canvas.getContext("2d"), viewport: bitmap })
    try {
      await entry.task.promise
    } catch (e) {
      if (e?.name === "RenderingCancelledException") return null
      throw e
    } finally {
      entry.task = null
    }
    if (!this.isCurrentCacheEntry(entry)) return null
    entry.ready = true
    return entry
  }

  isCurrentCacheEntry(entry) {
    return this.cacheGeneration === entry.generation && this.canvasCache.get(entry.pageNum) === entry
  }

  showCanvas(entry) {
    const changedPage = this.displayedPageNum !== entry.pageNum
    for (const cached of this.canvasCache.values()) cached.canvas.hidden = cached !== entry
    this.displayedPageNum = entry.pageNum
    this.baseViewport = entry.baseViewport
    // ページ寸法が混在する PDF では、めくった先のページにステージを追従させる。
    // 手動リサイズ後はユーザーが決めた枠寸法を尊重する。未リサイズ時だけ、
    // フィット表示またはページサイズ混在時に現在ページへステージを追従させる。
    if (!this.userResized && (this.fitted || changedPage)) this.sizeStage()
    this.statusTarget.textContent = ""
    this.pageInputTarget.value = entry.pageNum
    this.pageInputTarget.max = this.doc.numPages
    this.pageTotalTarget.textContent = this.doc.numPages
    this.pctTarget.textContent = `${Math.round(this.scale * 100)}%`
    this.stageTarget.classList.toggle("is-pannable", this.scrollable())
  }

  prefetchAdjacentPages(generation) {
    this.evictDistantCanvases()
    // 読み進み方向を先に開始する（右開きは番号の小さい側が「次」）。
    const advance = this.rtl ? this.pageNum - 1 : this.pageNum + 1
    const back = this.rtl ? this.pageNum + 1 : this.pageNum - 1
    for (const pageNum of [advance, back]) {
      if (pageNum < 1 || pageNum > this.doc.numPages) continue
      this.renderPage(pageNum, generation).catch(() => {}) // 先読み失敗は現在表示を妨げない
    }
  }

  evictDistantCanvases() {
    for (const [pageNum, entry] of this.canvasCache) {
      if (Math.abs(pageNum - this.pageNum) <= 1) continue
      entry.task?.cancel()
      entry.canvas.remove()
      this.canvasCache.delete(pageNum)
    }
  }

  clearCanvasCache() {
    this.cacheGeneration = (this.cacheGeneration || 0) + 1
    for (const entry of this.canvasCache?.values() || []) {
      entry.task?.cancel()
      entry.canvas.remove()
    }
    this.canvasCache?.clear()
    this.displayedPageNum = null
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

  zoomIn() { this.scale = (this.scale ?? 1) * 1.25; this.fitted = false; this.render({ invalidateCache: true }) }
  zoomOut() { this.scale = (this.scale ?? 1) / 1.25; this.fitted = false; this.render({ invalidateCache: true }) }
  actualSize() { this.scale = 1; this.fitted = false; this.render({ invalidateCache: true }) } // 等倍 (1pt = 1px)

  // フィット = 画面に合わせて再フィット。手動リサイズ/移動の解除（リセット）も兼ねる。
  fit() {
    if (!this.baseViewport) return
    this.userResized = false
    this.scale = this.fitScaleFor(this.baseViewport)
    this.fitted = true
    this.sizeStage()
    this.render({ invalidateCache: true })
  }

  // ダブルクリック: ほぼフィットなら等倍へ、それ以外はフィットへ。
  toggleZoom() {
    if (!this.baseViewport) return
    const fs = this.fitScaleFor(this.baseViewport)
    if (Math.abs(this.scale - fs) < 0.01) { this.scale = 1; this.fitted = false } else { this.scale = fs; this.fitted = true }
    this.render({ invalidateCache: true })
  }

  // ウィンドウのリサイズ/回転時、フィット表示中ならフィット倍率を取り直して追従する。
  handleResize() {
    if (!this.doc || !this.dialogTarget.open || !this.fitted || !this.baseViewport) return
    if (this.userResized) return // 手動リサイズ後は window リサイズで勝手に変えない
    this.scale = this.fitScaleFor(this.baseViewport)
    this.sizeStage()
    this.render({ invalidateCache: true })
  }
}
