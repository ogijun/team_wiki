import { Controller } from "@hotwired/stimulus"

// トップバーの検索。アイコン（円形）だけ出しておき、押すとトップバーに重なる
// オーバーレイで検索窓を出す（全画面サイズで同じ挙動）。
// 外側クリック・Esc・×・ページ遷移で閉じる。開いている間はトグルを隠す（CSS 側）。
export default class extends Controller {
  static targets = ["overlay", "input", "toggle", "close"]

  connect() {
    this.onDocClick = (e) => { if (!this.element.contains(e.target)) this.close() }
    this.onKeydown = (e) => {
      if (this.overlayTarget.hidden) return
      if (e.key === "Escape") { this.close(); return }
      if (e.key === "Tab") this.trapFocus(e)
    }
    // Turbo 遷移時は静かに閉じる（離脱中なのでフォーカスは戻さない）。
    this.onBeforeVisit = () => { this.overlayTarget.hidden = true }
    document.addEventListener("click", this.onDocClick)
    document.addEventListener("keydown", this.onKeydown)
    document.addEventListener("turbo:before-visit", this.onBeforeVisit)
  }

  disconnect() {
    document.removeEventListener("click", this.onDocClick)
    document.removeEventListener("keydown", this.onKeydown)
    document.removeEventListener("turbo:before-visit", this.onBeforeVisit)
  }

  open() {
    this.overlayTarget.hidden = false
    this.toggleTarget.setAttribute("aria-expanded", "true")
    this.inputTarget.focus()
  }

  close() {
    if (this.overlayTarget.hidden) return
    this.overlayTarget.hidden = true
    this.toggleTarget.setAttribute("aria-expanded", "false")
    // 閉じたらトリガーにフォーカスを戻す（キーボード操作の流れを保つ）。
    this.toggleTarget.focus()
  }

  // オーバーレイは背後の要素（アバター等）に重なるので、Tab がその裏へ抜けないよう
  // 入力欄と×ボタンの2点間でフォーカスを循環させる。
  trapFocus(e) {
    const first = this.inputTarget
    const last = this.closeTarget
    if (e.shiftKey && document.activeElement === first) {
      e.preventDefault()
      last.focus()
    } else if (!e.shiftKey && document.activeElement === last) {
      e.preventDefault()
      first.focus()
    }
  }
}
