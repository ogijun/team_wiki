import { Controller } from "@hotwired/stimulus"

// 記事の日付範囲。終了欄だけを段階的に開示する。
export default class extends Controller {
  static targets = ["end", "endLink"]

  connect() {
    if (this.endTarget.querySelector("input")?.value.trim()) this.openEnd()
  }

  addEnd(event) {
    event.preventDefault()
    this.openEnd()
  }

  // 終了行ごと未指定に戻す（入力を全クリアし、行を隠して「期間を指定」リンクを戻す）
  removeEnd(event) {
    event.preventDefault()
    this.clearInputs(this.endTarget)
    this.hide(this.endTarget)
    this.show(this.endLinkTarget)
  }

  openEnd() {
    this.show(this.endTarget)
    this.hide(this.endLinkTarget)
  }

  // --- DOM ヘルパ ---
  show(el) { el.hidden = false }
  hide(el) { el.hidden = true }
  clearInputs(el) { el.querySelectorAll("input").forEach((input) => { input.value = "" }) }
}
