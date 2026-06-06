import { Controller } from "@hotwired/stimulus"

// data-clipboard-text-value の文字列をクリップボードへコピーし、ボタンに一時フィードバック。
// http(非secure context)でも動くよう execCommand フォールバックを持つ。
export default class extends Controller {
  static values = { text: String }

  async copy(event) {
    const btn = event.currentTarget
    let ok = false
    try {
      if (navigator.clipboard && window.isSecureContext) {
        await navigator.clipboard.writeText(this.textValue)
        ok = true
      } else {
        ok = this.fallback(this.textValue)
      }
    } catch {
      ok = this.fallback(this.textValue)
    }
    this.flash(btn, ok ? "コピーしました" : "コピーできませんでした")
  }

  fallback(text) {
    const ta = document.createElement("textarea")
    ta.value = text
    ta.style.position = "fixed"
    ta.style.opacity = "0"
    document.body.appendChild(ta)
    ta.select()
    let ok = false
    try { ok = document.execCommand("copy") } catch { ok = false }
    document.body.removeChild(ta)
    return ok
  }

  flash(btn, message) {
    const original = btn.dataset.label || btn.textContent
    btn.dataset.label = original
    btn.textContent = message
    setTimeout(() => { btn.textContent = original }, 1500)
  }
}
