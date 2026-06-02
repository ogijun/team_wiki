import { Controller } from "@hotwired/stimulus"

// 粗い項目が空なら細かい項目を disabled にする（開始フィールドの段階有効化）
export default class extends Controller {
  static targets = ["year", "month", "day", "hour", "minute"]

  connect() { this.refresh() }

  refresh() {
    const hasYear = this.has(this.yearTarget)
    const hasMonth = hasYear && this.has(this.monthTarget)
    const hasDay = hasMonth && this.has(this.dayTarget)
    const hasHour = hasDay && this.has(this.hourTarget)

    this.monthTarget.disabled = !hasYear
    this.dayTarget.disabled = !hasMonth
    this.hourTarget.disabled = !hasDay
    this.minuteTarget.disabled = !hasHour
  }

  has(el) { return el.value.toString().trim() !== "" }
}
