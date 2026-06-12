import { Controller } from "@hotwired/stimulus"

// 汎用の開閉ビューア（画像の原寸表示など）。viewer ターゲットの hidden をトグルするだけ。
// 中の <img loading="lazy"> は hidden の間は取得されないので、開くまで原寸は読まれない。
export default class extends Controller {
  static targets = ["viewer"]

  toggle(event) {
    event.preventDefault()
    this.viewerTarget.hidden = !this.viewerTarget.hidden
  }
}
