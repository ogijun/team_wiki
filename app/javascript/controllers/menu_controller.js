import { Controller } from "@hotwired/stimulus"

// <details> ベースのドロップダウンメニューを、外側クリック・Esc・ページ遷移で閉じる。
// data-controller="menu" を <details> に付けるだけ（native の開閉はそのまま使う）。
export default class extends Controller {
  connect() {
    this.onDocClick = (e) => { if (!this.element.contains(e.target)) this.close() }
    this.onKeydown = (e) => { if (e.key === "Escape") this.close() }
    document.addEventListener("click", this.onDocClick)
    document.addEventListener("keydown", this.onKeydown)
    // Turbo 遷移時に開いたまま残らないようにする。
    this.onBeforeVisit = () => this.close()
    document.addEventListener("turbo:before-visit", this.onBeforeVisit)
    // メニュー内リンクのクリックでも閉じる（遷移しない anchor の場合の保険）。
    this.onItemClick = (e) => {
      if (e.target.closest("a, button") && e.target.closest("summary") === null) this.close()
    }
    this.element.addEventListener("click", this.onItemClick)
  }

  disconnect() {
    document.removeEventListener("click", this.onDocClick)
    document.removeEventListener("keydown", this.onKeydown)
    document.removeEventListener("turbo:before-visit", this.onBeforeVisit)
    this.element.removeEventListener("click", this.onItemClick)
  }

  close() {
    this.element.removeAttribute("open")
  }
}
