import { Controller } from "@hotwired/stimulus"

// Facebook のイベント風に、日時UIを段階的に開示する。
// 初期は単一日時（年月日）のみ。「時間を追加」で時刻欄、「期間を指定」で終了行を出す。
// 「開始:」ラベルは期間指定後にのみ表示する。
// 編集時は値があるセクションを自動展開する。
export default class extends Controller {
  static targets = [
    "startLabel",
    "startTime", "startTimeLink", "startHour",
    "end", "endLink",
    "endTime", "endTimeLink", "endYear", "endHour"
  ]

  connect() {
    if (this.hasValue(this.startHourTarget)) this.showStartTime()
    if (this.hasValue(this.endYearTarget)) this.openEnd()
    if (this.hasValue(this.endHourTarget)) this.showEndTime()
  }

  // 開始・終了のどちらかで時間を開いたら両方開く（終了行が出ている場合）
  addStartTime(event) {
    event.preventDefault()
    this.showStartTime()
    if (!this.endTarget.hidden) this.showEndTime()
  }

  addEndTime(event) {
    event.preventDefault()
    this.showEndTime()
    this.showStartTime()
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
    this.hide(this.startLabelTarget)
    // 終了時刻欄の状態も初期化
    this.hide(this.endTimeTarget)
    this.show(this.endTimeLinkTarget)
  }

  openEnd() {
    this.show(this.endTarget)
    this.hide(this.endLinkTarget)
    this.show(this.startLabelTarget)
    // 開始で時間入力が出ているなら、終了も最初から時間欄を出す
    if (!this.startTimeTarget.hidden) this.showEndTime()
  }

  showStartTime() {
    this.show(this.startTimeTarget)
    this.hide(this.startTimeLinkTarget)
  }

  showEndTime() {
    this.show(this.endTimeTarget)
    this.hide(this.endTimeLinkTarget)
  }

  // --- DOM ヘルパ ---
  show(el) { el.hidden = false }
  hide(el) { el.hidden = true }
  clearInputs(el) { el.querySelectorAll("input").forEach((input) => { input.value = "" }) }
  hasValue(el) { return el && el.value.toString().trim() !== "" }
}
