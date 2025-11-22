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
  initAutoSubmitControls()
  initVehicleFinancialsFullscreen()
  initPeriodRadios()

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

function initAutoSubmitControls () {
  document.querySelectorAll(".js-auto-submit").forEach((el) => {
    if (el.dataset.autoSubmitBound === "true") return
    el.addEventListener("change", () => {
      const form = el.closest("form")
      if (form) form.requestSubmit()
    })
    el.dataset.autoSubmitBound = "true"
  })
}

function initVehicleFinancialsFullscreen () {
  const button = document.querySelector(".js-vehicle-financials-fullscreen")
  if (!button || button.dataset.fullscreenBound === "true") return

  const targetSelector = button.dataset.fullscreenTarget || ".vehicle-financials-container"
  const target = document.querySelector(targetSelector)
  if (!target) return

  const isFullscreen = () => {
    return document.fullscreenElement === target || document.webkitFullscreenElement === target
  }

  const updateLabel = () => {
    button.textContent = isFullscreen() ? "フルスクリーン解除" : "フルスクリーン"
  }

  const requestFullscreen = () => {
    if (target.requestFullscreen) {
      target.requestFullscreen()
    } else if (target.webkitRequestFullscreen) {
      target.webkitRequestFullscreen()
    }
  }

  const exitFullscreen = () => {
    if (document.exitFullscreen) {
      document.exitFullscreen()
    } else if (document.webkitExitFullscreen) {
      document.webkitExitFullscreen()
    }
  }

  button.addEventListener("click", () => {
    if (isFullscreen()) {
      exitFullscreen()
    } else {
      requestFullscreen()
    }
  })

  document.addEventListener("fullscreenchange", updateLabel)
  document.addEventListener("webkitfullscreenchange", updateLabel)
  updateLabel()
  button.dataset.fullscreenBound = "true"
}

function initPeriodRadios () {
  document.querySelectorAll(".js-period").forEach((radio) => {
    if (radio.dataset.periodBound === "true") return
    radio.addEventListener("change", () => {
      const form = radio.closest("form")
      if (form) form.requestSubmit()
    })
    radio.dataset.periodBound = "true"
  })
}
