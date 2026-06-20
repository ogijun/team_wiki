import { Controller } from "@hotwired/stimulus"

// 「初出」の時刻入力（時:分）を既定で隠し、「＋時刻」ボタンで開く。
// 既に時刻が入っている資料（編集時）では接続時に自動で開く。
export default class extends Controller {
  static targets = ["times", "toggle"]

  connect() {
    if (this.hasTimesTarget && this.hasValue()) this.reveal()
  }

  open(event) {
    event.preventDefault()
    this.reveal()
  }

  reveal() {
    this.timesTarget.hidden = false
    if (this.hasToggleTarget) this.toggleTarget.hidden = true
  }

  hasValue() {
    return Array.from(this.timesTarget.querySelectorAll("input")).some((i) => i.value !== "")
  }
}
