import { Controller } from "@hotwired/stimulus"

// トップバーの検索。アイコンだけ出しておき、押すとトップバーを覆うオーバーレイで
// 検索窓を出す（全画面サイズで同じ挙動）。外側クリック・Esc・×・ページ遷移で閉じる。
export default class extends Controller {
  static targets = ["overlay", "input", "toggle"]

  connect() {
    this.onDocClick = (e) => { if (!this.element.contains(e.target)) this.close() }
    this.onKeydown = (e) => { if (e.key === "Escape") this.close() }
    // Turbo 遷移時に開いたまま残らないようにする。
    this.onBeforeVisit = () => this.close()
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
}
