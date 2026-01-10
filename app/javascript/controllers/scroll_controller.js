import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["container"]

  connect() {
    this.scrollToBottom()
    this.observeNewMessages()
  }

  disconnect() {
    if (this.observer) {
      this.observer.disconnect()
    }
  }

  scrollToBottom() {
    const container = this.hasContainerTarget ? this.containerTarget : this.element
    container.scrollTop = container.scrollHeight
  }

  observeNewMessages() {
    const container = this.hasContainerTarget ? this.containerTarget : this.element

    this.observer = new MutationObserver((mutations) => {
      const hasNewContent = mutations.some(mutation =>
        mutation.type === "childList" && mutation.addedNodes.length > 0
      )
      if (hasNewContent) {
        this.scrollToBottom()
      }
    })

    this.observer.observe(container, {
      childList: true,
      subtree: true
    })
  }
}
