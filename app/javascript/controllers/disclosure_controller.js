import { Controller } from "@hotwired/stimulus"

// 「ほかN件」をクリックすると、隠していた残りの対象名をインライン表示し、ボタンを隠す。
export default class extends Controller {
  static targets = ["rest", "toggle"]

  toggle() {
    this.restTargets.forEach((el) => (el.hidden = false))
    if (this.hasToggleTarget) this.toggleTarget.hidden = true
  }
}
