import { Controller } from "@hotwired/stimulus"

// Facebook のイベント風に、日時UIを段階的に開示する。
// 初期は開始の年月日のみ。「時間を追加」で時刻欄、「期間を指定」で終了行を出す。
// 編集時は値があるセクションを自動展開する。
export default class extends Controller {
  static targets = [
    "startTime", "startTimeLink", "startHour",
    "end", "endLink",
    "endTime", "endTimeLink", "endYear", "endHour"
  ]

  connect() {
    if (this.hasValue(this.startHourTarget)) this.reveal(this.startTimeTarget, this.startTimeLinkTarget)
    if (this.hasValue(this.endYearTarget)) this.reveal(this.endTarget, this.endLinkTarget)
    if (this.hasValue(this.endHourTarget)) this.reveal(this.endTimeTarget, this.endTimeLinkTarget)
  }

  addStartTime(event) { event.preventDefault(); this.reveal(this.startTimeTarget, this.startTimeLinkTarget) }
  addEnd(event) { event.preventDefault(); this.reveal(this.endTarget, this.endLinkTarget) }
  addEndTime(event) { event.preventDefault(); this.reveal(this.endTimeTarget, this.endTimeLinkTarget) }

  reveal(section, link) {
    section.hidden = false
    if (link) link.hidden = true
  }

  hasValue(el) { return el && el.value.toString().trim() !== "" }
}
