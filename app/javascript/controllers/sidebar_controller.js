import { Controller } from "@hotwired/stimulus"

// 左サイドナビの開閉（狭い画面のドロワー用）。広い画面では常時表示で no-op。
// data-controller="sidebar" を body に付け、open クラスのトグルで CSS が表示を切り替える。
export default class extends Controller {
  toggle() {
    this.element.classList.toggle("sidebar-open")
  }

  close() {
    this.element.classList.remove("sidebar-open")
  }
}
