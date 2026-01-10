import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "submit"]

  connect() {
    this.inputTarget.focus()
    this.resize()
  }

  submit(event) {
    event.preventDefault()
    if (this.inputTarget.value.trim() === "") return

    this.submitTarget.click()
  }

  resize() {
    const input = this.inputTarget
    input.style.height = "auto"
    input.style.height = Math.min(input.scrollHeight, 200) + "px"
  }

  reset() {
    this.inputTarget.value = ""
    this.resize()
    this.inputTarget.focus()
  }
}
