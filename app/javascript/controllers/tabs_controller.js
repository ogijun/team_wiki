import { Controller } from "@hotwired/stimulus"

// パネルを hidden トグルで切り替えるタブ。先頭タブを初期表示。
// JS 無効時は全パネルが表示されたままなので機能は損なわれない（プログレッシブ拡張）。
export default class extends Controller {
  static targets = ["tab", "panel"]

  connect() {
    const first = this.tabTargets[0]
    if (first) this.activate(first.dataset.key)
  }

  select(event) {
    this.activate(event.currentTarget.dataset.key)
  }

  activate(key) {
    this.panelTargets.forEach((p) => (p.hidden = p.dataset.key !== key))
    this.tabTargets.forEach((t) => t.classList.toggle("is-active", t.dataset.key === key))
  }
}
