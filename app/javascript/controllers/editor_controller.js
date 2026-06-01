import { Controller } from "@hotwired/stimulus"

// toast-ui editor を textarea に重ねて初期化し、保存時に Markdown を textarea へ書き戻す。
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
}
