import { Controller } from "@hotwired/stimulus"

// 汎用のオーバーレイビューア（画像の原寸表示など）。<dialog> を showModal で開く。
// 閉じるのは ESC（dialog 標準）か背景クリック。閉じている間は display:none なので
// 中の <img loading="lazy"> は開くまで取得されない。
export default class extends Controller {
  static targets = ["dialog"]

  open(event) {
    event.preventDefault()
    this.dialogTarget.showModal()
  }

  // dialog 自身（=背景余白）がクリックされたときだけ閉じる
  backdropClose(event) {
    if (event.target === this.dialogTarget) this.dialogTarget.close()
  }
}
