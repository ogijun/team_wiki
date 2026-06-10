import { Controller } from "@hotwired/stimulus"
import { get, post } from "@rails/request.js"

// toast-ui editor を textarea に重ねて初期化し、保存時に Markdown を textarea へ書き戻す。
// ツールバーに「出典」ボタンを追加し、資料を選んで [[ref:slug]] を挿入できる。
export default class extends Controller {
  static targets = ["source"]

  connect() {
    this.textarea = this.sourceTarget
    this.textarea.style.display = "none"

    this.holder = document.createElement("div")
    this.textarea.after(this.holder)

    this.editor = new toastui.Editor({
      el: this.holder,
      height: "500px",
      initialEditType: "markdown",
      previewStyle: "vertical",
      initialValue: this.textarea.value,
      hooks: {
        addImageBlobHook: (blob, callback) => this.upload(blob, callback)
      }
    })

    this.addCitationButton()

    // Turbo がページをキャッシュする前に片付ける。キャッシュにマウント済みエディタの
    // 残骸が残ると、復元＋再 connect で空のエディタが二重化し空白になるため。
    this.beforeCache = () => this.teardown()
    document.addEventListener("turbo:before-cache", this.beforeCache)
  }

  // フォーム submit 時に Markdown を textarea へ書き戻す（data-action="submit->editor#writeBack"）。
  writeBack() {
    if (this.editor) this.textarea.value = this.editor.getMarkdown()
  }

  disconnect() {
    document.removeEventListener("turbo:before-cache", this.beforeCache)
    this.teardown()
  }

  teardown() {
    if (this.editor) { this.editor.destroy(); this.editor = null }
    if (this.holder) { this.holder.remove(); this.holder = null }
    if (this.textarea) this.textarea.style.display = ""
  }

  async upload(blob, callback) {
    const data = new FormData()
    data.append("file", blob)
    const res = await post("/uploads", { body: data })
    if (res.ok) {
      const json = await res.json
      callback(json.url, "uploaded")
    } else {
      alert("アップロードに失敗しました")
    }
  }

  // ツールバーに「出典」ボタン + 資料ピッカーのポップアップを追加する。
  addCitationButton() {
    const button = document.createElement("button")
    button.type = "button"
    button.textContent = "出典"
    button.className = "citation-btn"

    const popup = document.createElement("div")
    popup.className = "citation-picker"

    const search = document.createElement("input")
    search.type = "search"
    search.placeholder = "資料を絞り込み"
    search.className = "citation-picker__search"

    const list = document.createElement("ul")
    list.className = "citation-list"

    popup.append(search, list)

    this.editor.insertToolbarItem(
      { groupIndex: 3, itemIndex: 0 },
      { name: "ref", tooltip: "出典を挿入", el: button, popup: { body: popup, style: { width: "320px" } } }
    )

    this.citationList = list
    this.citationSearch = search
    search.addEventListener("input", () => this.renderCitations())
    this.loadCitations()
  }

  async loadCitations() {
    try {
      const res = await get("/materials.json", { responseKind: "json" })
      this.citations = res.ok ? await res.json : []
    } catch {
      this.citations = []
    }
    this.renderCitations()
  }

  renderCitations() {
    const q = (this.citationSearch.value || "").toLowerCase()
    const items = (this.citations || []).filter((c) => c.title.toLowerCase().includes(q))
    this.citationList.replaceChildren()

    if (items.length === 0) {
      const empty = document.createElement("li")
      empty.textContent = this.citations && this.citations.length ? "該当なし" : "資料がありません"
      empty.className = "citation-list__empty"
      this.citationList.append(empty)
      return
    }

    items.forEach((c) => {
      const li = document.createElement("li")
      if (c.thumb_url) {
        const img = document.createElement("img")
        img.src = c.thumb_url
        img.className = "citation-thumb"
        img.loading = "lazy"
        li.append(img)
      }
      const link = document.createElement("button")
      link.type = "button"
      link.textContent = c.title
      link.addEventListener("click", () => this.insertCitation(c.slug))
      li.append(link)
      this.citationList.append(li)
    })
  }

  insertCitation(slug) {
    this.editor.insertText(`[[ref:${slug}]]`)
    try {
      this.editor.eventEmitter.emit("closePopup")
    } catch {
      // ポップアップを閉じる API が無い版では無視（ボタン再クリックで閉じる）
    }
  }
}
