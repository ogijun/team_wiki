import { Controller } from "@hotwired/stimulus"

// toast-ui editor を textarea に重ねて初期化し、保存時に Markdown を textarea へ書き戻す。
// ツールバーに「出典」ボタンを追加し、資料を選んで [[ref:slug]] を挿入できる。
export default class extends Controller {
  static targets = ["source"]

  connect() {
    this.textarea = this.sourceTarget
    this.textarea.style.display = "none"

    const holder = document.createElement("div")
    this.textarea.after(holder)

    this.editor = new toastui.Editor({
      el: holder,
      height: "500px",
      initialEditType: "markdown",
      previewStyle: "vertical",
      initialValue: this.textarea.value,
      hooks: {
        addImageBlobHook: (blob, callback) => this.upload(blob, callback)
      }
    })

    this.addCitationButton()

    this.form = this.textarea.closest("form")
    this.onSubmit = () => { this.textarea.value = this.editor.getMarkdown() }
    this.form.addEventListener("submit", this.onSubmit)
  }

  disconnect() {
    if (this.form) this.form.removeEventListener("submit", this.onSubmit)
    if (this.editor) this.editor.destroy()
  }

  async upload(blob, callback) {
    const data = new FormData()
    data.append("file", blob)
    const token = document.querySelector('meta[name="csrf-token"]').content
    const res = await fetch("/uploads", {
      method: "POST",
      headers: { "X-CSRF-Token": token },
      body: data
    })
    if (res.ok) {
      const json = await res.json()
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
      const res = await fetch("/materials.json", { headers: { Accept: "application/json" } })
      this.citations = res.ok ? await res.json() : []
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
