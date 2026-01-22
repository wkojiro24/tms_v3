import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["panel", "trigger"]
  static values = { active: String }

  connect() {
    if (!this.hasActiveValue) {
      this.activeValue = "fault"
    }
    this.showActivePanel()
  }

  select(event) {
    const type = event.currentTarget.dataset.type
    if (type) {
      this.activeValue = type
      this.showActivePanel()
    }
  }

  showActivePanel() {
    this.panelTargets.forEach((panel) => {
      panel.hidden = panel.dataset.type !== this.activeValue
    })
    this.triggerTargets.forEach((button) => {
      const isActive = button.dataset.type === this.activeValue
      button.classList.toggle("btn-primary", isActive)
      button.classList.toggle("btn-outline-secondary", !isActive)
    })
  }
}
