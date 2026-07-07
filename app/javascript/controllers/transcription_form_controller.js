import { Controller } from "@hotwired/stimulus"

// 文字起こしパートの編集で、見出しと本文を両方空にして保存しようとしたとき、
// そのパートを削除するか確認する。唯一のパート/新規作成のとき（can-delete=false）は
// 確認せず通常送信＝本文必須バリデーションに委ねる（＝空のままでは保存も削除もされない）。
export default class extends Controller {
  static targets = ["label", "body"]
  static values = { canDelete: Boolean }

  guard(event) {
    const filled = (el) => el && el.value.trim() !== ""
    if (filled(this.labelTarget) || filled(this.bodyTarget)) return // 通常保存
    if (!this.canDeleteValue) return // 唯一のパート/新規 → 通常フロー（本文必須エラー）

    if (window.confirm("見出しも本文も空です。このパートを削除しますか？")) {
      // PATCH(更新) を同URLの DELETE(destroy) に振り替える（Rails の _method オーバーライド）。
      const method = this.element.querySelector('input[name="_method"]')
      if (method) method.value = "delete"
    } else {
      event.preventDefault()
    }
  }
}
