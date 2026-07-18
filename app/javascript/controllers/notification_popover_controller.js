import { Controller } from "@hotwired/stimulus"

// お知らせを開いた時点で、遅延ロードによる既読化を待たずバッジを隠す。
export default class extends Controller {
  static targets = ["badge"]

  markRead() {
    this.badgeTarget?.remove()
  }
}
