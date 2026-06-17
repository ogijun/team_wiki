import { Controller } from "@hotwired/stimulus"

// flash トースト。data-auto="true"（notice）のトーストは delay 後に自動で消す。
// × クリック（toast#dismiss）はどのトーストも即時に消す。フェードアウトしてから DOM 除去。
export default class extends Controller {
  static targets = ["toast"]
  static values = { delay: { type: Number, default: 5000 } }

  connect() {
    this.timers = []
    this.toastTargets.forEach((el) => {
      if (el.dataset.auto === "true") {
        this.timers.push(setTimeout(() => this.remove(el), this.delayValue))
      }
    })
  }

  disconnect() {
    this.timers.forEach(clearTimeout)
  }

  dismiss(event) {
    this.remove(event.currentTarget.closest("[data-toast-target='toast']"))
  }

  remove(el) {
    if (!el || el.dataset.leaving) return
    el.dataset.leaving = "true"
    el.classList.add("toast--leaving")
    el.addEventListener("transitionend", () => el.remove(), { once: true })
    // transition が効かない環境のフォールバック
    setTimeout(() => el.remove(), 400)
  }
}
