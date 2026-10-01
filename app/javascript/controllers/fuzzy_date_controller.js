import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "preview"]
  static values = { url: String }

  connect() { this.preview() }

  preview() {
    clearTimeout(this.timer)
    this.timer = setTimeout(async () => {
      const url = `${this.urlValue}?text=${encodeURIComponent(this.inputTarget.value)}`
      const response = await fetch(url, { headers: { Accept: "text/plain" } })
      if (response.ok) this.previewTarget.textContent = `→ ${await response.text()}`
    }, 150)
  }
}
