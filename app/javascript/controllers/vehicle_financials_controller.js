import { Controller } from "@hotwired/stimulus"

// vehicle_financials ページのフィルター制御
export default class extends Controller {
  static targets = ["modePanel", "form", "vehicleSelect", "periodTab", "breakdownPopup"]
  static values = { breakdown: Object }

  connect() {
    this.updatePanelVisibility()
    this.setupBreakdownPopup()
  }

  disconnect() {
    this.removeBreakdownPopup()
  }

  setupBreakdownPopup() {
    // ポップアップ要素を作成
    if (!document.getElementById('breakdown-popup')) {
      const popup = document.createElement('div')
      popup.id = 'breakdown-popup'
      popup.className = 'breakdown-popup'
      popup.style.cssText = 'display:none; position:fixed; z-index:9999; background:#fff; border:1px solid #dee2e6; border-radius:8px; box-shadow:0 4px 12px rgba(0,0,0,0.15); max-width:320px; max-height:400px; overflow-y:auto;'
      document.body.appendChild(popup)

      // ポップアップ外クリックで閉じる
      document.addEventListener('click', (e) => {
        const popup = document.getElementById('breakdown-popup')
        if (popup && popup.style.display !== 'none') {
          if (!popup.contains(e.target) && !e.target.closest('[data-breakdown-cell]')) {
            popup.style.display = 'none'
          }
        }
      })
    }
  }

  removeBreakdownPopup() {
    const popup = document.getElementById('breakdown-popup')
    if (popup) popup.remove()
  }

  // 表示モード変更時
  changeMode(event) {
    this.updatePanelVisibility()
  }

  // パネルの表示/非表示を切り替え
  updatePanelVisibility() {
    const selectedMode = this.element.querySelector('input[name="view_mode"]:checked')?.value || "monthly"

    this.modePanelTargets.forEach(panel => {
      const panelMode = panel.dataset.mode
      if (panelMode === selectedMode) {
        panel.style.display = ""
      } else {
        panel.style.display = "none"
      }
    })
  }

  // 期タブクリック時に自動サブミット
  selectPeriod(event) {
    // ラジオボタンが選択されたら自動でフォームをサブミット
    setTimeout(() => {
      this.formTarget.submit()
    }, 50)
  }

  // 自動サブミット（select変更時）
  autoSubmit(event) {
    this.formTarget.submit()
  }

  // 車両選択をクリア
  clearVehicles(event) {
    event.preventDefault()
    // 個別選択をクリア
    if (this.hasVehicleSelectTarget) {
      const select = this.vehicleSelectTarget
      Array.from(select.options).forEach(option => {
        option.selected = false
      })
    }
    // グループ選択もクリア
    const groupSelect = this.element.querySelector('select[name="vehicle_group_id"]')
    if (groupSelect) {
      groupSelect.value = ""
    }
    // フォームをサブミット
    this.formTarget.submit()
  }

  // フルスクリーン切り替え
  toggleFullscreen(event) {
    event.preventDefault()
    const target = document.querySelector(event.currentTarget.dataset.fullscreenTarget)
    if (!target) return

    if (document.fullscreenElement) {
      document.exitFullscreen()
    } else {
      target.requestFullscreen()
    }
  }

  // 内訳セルをクリック
  showBreakdown(event) {
    event.preventDefault()
    event.stopPropagation()

    const cell = event.currentTarget
    const label = cell.dataset.breakdownLabel
    const monthKey = cell.dataset.breakdownMonth

    // breakdownデータを取得
    const breakdownData = this.breakdownValue
    if (!breakdownData || !breakdownData[label] || !breakdownData[label][monthKey]) {
      return
    }

    const items = breakdownData[label][monthKey]
    const popup = document.getElementById('breakdown-popup')
    if (!popup) return

    // ソート（値の大きい順）
    const sortedItems = [...items].sort((a, b) => Math.abs(b.value || 0) - Math.abs(a.value || 0))

    // 合計を計算
    const total = sortedItems.reduce((sum, item) => sum + (item.value || 0), 0)

    // ポップアップの内容を生成
    let html = `
      <div style="padding:12px; border-bottom:1px solid #eee;">
        <div style="font-weight:600; font-size:13px;">${this.escapeHtml(label)}</div>
        <div style="color:#6c757d; font-size:11px;">${monthKey}</div>
      </div>
      <div style="padding:8px 12px;">
        <table style="width:100%; font-size:12px; border-collapse:collapse;">
          <thead>
            <tr style="border-bottom:1px solid #eee;">
              <th style="text-align:left; padding:4px 8px 4px 0; color:#6c757d;">車両</th>
              <th style="text-align:right; padding:4px 0 4px 8px; color:#6c757d;">金額</th>
            </tr>
          </thead>
          <tbody>
    `

    sortedItems.forEach(item => {
      const value = item.value || 0
      const formattedValue = this.formatNumber(value)
      const valueClass = value < 0 ? 'color:#dc3545;' : ''
      const valueStyle = value !== 0 ? '' : 'color:#adb5bd;'

      html += `
        <tr style="border-bottom:1px solid #f8f9fa;">
          <td style="padding:6px 8px 6px 0;">
            <code style="font-size:11px; background:#f8f9fa; padding:2px 4px; border-radius:3px;">${this.escapeHtml(item.code)}</code>
          </td>
          <td style="text-align:right; padding:6px 0 6px 8px; font-family:monospace; ${valueClass}${valueStyle}">
            ${formattedValue}
          </td>
        </tr>
      `
    })

    html += `
          </tbody>
          <tfoot>
            <tr style="border-top:2px solid #dee2e6; font-weight:600;">
              <td style="padding:8px 8px 8px 0;">合計</td>
              <td style="text-align:right; padding:8px 0 8px 8px; font-family:monospace; ${total < 0 ? 'color:#dc3545;' : ''}">
                ${this.formatNumber(total)}
              </td>
            </tr>
          </tfoot>
        </table>
      </div>
    `

    popup.innerHTML = html

    // ポップアップの位置を設定
    const rect = cell.getBoundingClientRect()
    const popupWidth = 320
    const popupHeight = Math.min(400, sortedItems.length * 36 + 120)

    let left = rect.left + rect.width / 2 - popupWidth / 2
    let top = rect.bottom + 8

    // 画面外にはみ出さないように調整
    if (left < 8) left = 8
    if (left + popupWidth > window.innerWidth - 8) left = window.innerWidth - popupWidth - 8
    if (top + popupHeight > window.innerHeight - 8) {
      top = rect.top - popupHeight - 8
    }

    popup.style.left = `${left}px`
    popup.style.top = `${top}px`
    popup.style.display = 'block'
  }

  // 数値をフォーマット
  formatNumber(value) {
    if (value === null || value === undefined) return '-'
    const num = Math.round(value)
    return num.toLocaleString('ja-JP')
  }

  // HTMLエスケープ
  escapeHtml(text) {
    const div = document.createElement('div')
    div.textContent = text
    return div.innerHTML
  }
}
