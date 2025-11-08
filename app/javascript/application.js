// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"
import * as bootstrap from "bootstrap"

const SIDEBAR_STATE_KEY = "tms:sidebar-expanded"
const SIDEBAR_SECTION_KEY_PREFIX = "tms:sidebar-section:"

document.addEventListener("turbo:load", () => {
  applySidebarState()
  initSidebarSections()
  recalcSidebarSectionHeights()

  document.querySelectorAll("[data-toggle-sidebar]").forEach((button) => {
    button.addEventListener("click", () => {
      const expanded = document.body.classList.toggle("sidebar-expanded")
      localStorage.setItem(SIDEBAR_STATE_KEY, expanded ? "true" : "false")
      recalcSidebarSectionHeights()
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

function initSidebarSections () {
  document.querySelectorAll("[data-toggle-sidebar-section]").forEach((button) => {
    const sectionName = button.dataset.toggleSidebarSection
    if (!sectionName) return

    const body = document.querySelector(`[data-sidebar-section-body='${sectionName}']`)
    if (!body) return

    const stored = localStorage.getItem(SIDEBAR_SECTION_KEY_PREFIX + sectionName)
    const defaultExpanded = button.dataset.sectionDefault !== "collapsed"
    const expanded = stored == null ? defaultExpanded : stored === "true"

    setSidebarSectionExpanded(button, body, expanded)

    if (button.dataset.sectionBound === "true") return
    button.addEventListener("click", () => {
      const nextExpanded = button.getAttribute("aria-expanded") !== "true"
      setSidebarSectionExpanded(button, body, nextExpanded)
      localStorage.setItem(SIDEBAR_SECTION_KEY_PREFIX + sectionName, nextExpanded ? "true" : "false")
      recalcSidebarSectionHeights()
      initTooltips()
    })
    button.dataset.sectionBound = "true"
  })
}

function setSidebarSectionExpanded (button, body, expanded) {
  button.setAttribute("aria-expanded", expanded ? "true" : "false")
  body.classList.toggle("is-collapsed", !expanded)
  body.style.maxHeight = expanded ? `${body.scrollHeight}px` : "0px"
}

function recalcSidebarSectionHeights () {
  document.querySelectorAll(".app-sidebar__section-body").forEach((body) => {
    if (body.classList.contains("is-collapsed")) return
    body.style.maxHeight = `${body.scrollHeight}px`
  })
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

window.addEventListener("resize", recalcSidebarSectionHeights)
