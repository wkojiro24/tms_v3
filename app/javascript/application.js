// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"
import * as bootstrap from "bootstrap"

const SIDEBAR_STATE_KEY = "tms:sidebar-expanded"

document.addEventListener("turbo:load", () => {
  applySidebarState()

  document.querySelectorAll("[data-toggle-sidebar]").forEach((button) => {
    button.addEventListener("click", () => {
      const expanded = document.body.classList.toggle("sidebar-expanded")
      localStorage.setItem(SIDEBAR_STATE_KEY, expanded ? "true" : "false")
      initTooltips()
    })
  })

  initTooltips()
})

document.addEventListener("turbo:frame-load", (event) => {
  if (event.target.id === "journal_entries_frame") {
    initTooltips()
  }
})

function applySidebarState () {
  const stored = localStorage.getItem(SIDEBAR_STATE_KEY)
  if (stored === "true") {
    document.body.classList.add("sidebar-expanded")
  } else {
    document.body.classList.remove("sidebar-expanded")
  }
}

function initTooltips () {
  const Tooltip = bootstrap.Tooltip || (window.bootstrap && window.bootstrap.Tooltip)
  if (!Tooltip) return

  document.querySelectorAll("[data-bs-toggle='tooltip']").forEach((el) => {
    const existing = Tooltip.getInstance(el)
    if (existing) existing.dispose()

    Tooltip.getOrCreateInstance(el, {
      trigger: "hover focus",
      container: "body"
    })
  })
}
