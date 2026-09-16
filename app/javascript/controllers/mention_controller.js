import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "menu"]
  static values = { members: Array }

  connect() {
    this.activeIndex = 0
  }

  search() {
    const context = this.context()
    if (!context) return this.close()

    const query = context.query.toLocaleLowerCase()
    this.matches = this.membersValue
      .filter((member) => member.name.toLocaleLowerCase().includes(query))
      .slice(0, 8)
    this.activeIndex = 0
    this.render()
  }

  keydown(event) {
    if (this.menuTarget.hidden) return
    if (event.key === "Escape") return this.close()
    if (!["ArrowDown", "ArrowUp", "Enter"].includes(event.key)) return

    event.preventDefault()
    if (event.key === "ArrowDown") this.activeIndex = (this.activeIndex + 1) % this.matches.length
    if (event.key === "ArrowUp") this.activeIndex = (this.activeIndex - 1 + this.matches.length) % this.matches.length
    if (event.key === "Enter") return this.select(this.matches[this.activeIndex])
    this.render()
  }

  choose(event) {
    this.select(this.matches[Number(event.currentTarget.dataset.index)])
  }

  select(member) {
    const context = this.context()
    if (!context || !member) return this.close()

    const input = this.inputTarget
    const token = `@[${member.name}](${member.id}) `
    input.setRangeText(token, context.start, input.selectionStart, "end")
    input.focus()
    this.close()
  }

  context() {
    const input = this.inputTarget
    const beforeCursor = input.value.slice(0, input.selectionStart)
    const start = beforeCursor.lastIndexOf("@")
    if (start < 0 || (start > 0 && !/\s/.test(beforeCursor[start - 1]))) return null

    const query = beforeCursor.slice(start + 1)
    if (/[\n\r@\[\]()]/.test(query)) return null
    return { start, query }
  }

  render() {
    this.menuTarget.replaceChildren()
    this.matches.forEach((member, index) => {
      const button = document.createElement("button")
      button.type = "button"
      button.className = "mention-picker__option"
      button.dataset.index = index
      button.dataset.action = "mention#choose"
      button.textContent = `@${member.name}`
      if (index === this.activeIndex) button.classList.add("is-active")
      this.menuTarget.append(button)
    })
    this.menuTarget.hidden = this.matches.length === 0
  }

  close() {
    this.matches = []
    this.menuTarget.replaceChildren()
    this.menuTarget.hidden = true
  }
}
