import { Controller } from "@hotwired/stimulus"

// 「ほかN件」「＋時刻」など、隠していた内容をクリックで一方向に開き、トリガーを隠す。
// auto-reveal-if-set を指定すると、入力済みの編集フォームでは接続時に自動で開く。
export default class extends Controller {
  static targets = ["rest", "toggle"]
  static values = { autoRevealIfSet: Boolean }

  connect() {
    if (this.autoRevealIfSetValue && this.hasValue()) this.reveal()
  }

  toggle(event) {
    event?.preventDefault()
    this.reveal()
  }

  reveal() {
    this.restTargets.forEach((el) => (el.hidden = false))
    if (this.hasToggleTarget) this.toggleTarget.hidden = true
  }

  hasValue() {
    return this.restTargets.some((el) =>
      Array.from(el.querySelectorAll("input")).some((input) => input.value !== "")
    )
  }
}
