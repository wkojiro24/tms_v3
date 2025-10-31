import { Controller } from "@hotwired/stimulus"

// Handles dynamic addition/removal of file inputs for attachments.
export default class extends Controller {
  static targets = ["inputs", "template", "addButton"]
  static values = { maxFiles: Number }

  connect() {
    this.ensureAtLeastOneInput()
    this.updateAddButtonState()
  }

  add(event) {
    event.preventDefault()
    if (this.inputCount() >= this.maxFilesValue) return

    const clone = this.templateTarget.content.firstElementChild.cloneNode(true)
    this.inputsTarget.appendChild(clone)
    this.updateAddButtonState()
  }

  remove(event) {
    event.preventDefault()
    const element = event.target.closest("[data-attachments-element]")
    if (element) {
      element.remove()
    }
    this.ensureAtLeastOneInput()
    this.updateAddButtonState()
  }

  ensureAtLeastOneInput() {
    if (this.inputCount() === 0) {
      const clone = this.templateTarget.content.firstElementChild.cloneNode(true)
      this.inputsTarget.appendChild(clone)
    }
  }

  updateAddButtonState() {
    if (!this.hasAddButtonTarget) return
    const disabled = this.inputCount() >= this.maxFilesValue
    this.addButtonTarget.disabled = disabled
  }

  inputCount() {
    return this.inputsTarget.querySelectorAll("[data-attachments-element]").length
  }
}
