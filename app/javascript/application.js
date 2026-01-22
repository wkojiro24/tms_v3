// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"
import * as bootstrap from "bootstrap"

// Trix editor for Action Text
import "trix"
import "@rails/actiontext"

document.addEventListener("turbo:load", () => {
  initAutoSubmitControls()
  initVehicleFinancialsFullscreen()
  initPeriodRadios()
  initTooltips()
  initSidebarMenus()
})

function initSidebarMenus () {
  document.querySelectorAll("[data-toggle-menu]").forEach((btn) => {
    if (btn.dataset.menuBound === "true") return
    btn.addEventListener("click", () => {
      const submenu = btn.nextElementSibling
      if (submenu && submenu.classList.contains("app-sidebar__submenu")) {
        btn.classList.toggle("is-open")
        submenu.classList.toggle("is-open")
      }
    })
    btn.dataset.menuBound = "true"
  })
}

document.addEventListener("turbo:frame-load", (event) => {
  if (event.target.id === "journal_entries_frame") {
    initTooltips()
  }
})

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
