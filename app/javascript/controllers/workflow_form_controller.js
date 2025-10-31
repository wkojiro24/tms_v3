import { Controller } from "@hotwired/stimulus"

const TEMPLATES = {
  business_trip: {
    label: "出張申請",
    summaryHint: "出張の目的・背景、同行者や想定成果を記載してください。",
    sections: ["financial", "travel", "attachments"],
    required: ["summary", "metadata.travel_destination", "metadata.travel_start_on", "metadata.travel_end_on"],
    fields: [
      "title",
      "summary",
      "additional_information",
      "amount",
      "currency",
      "vendor_name",
      "needed_on",
      "metadata.travel_destination",
      "metadata.travel_purpose",
      "metadata.travel_start_on",
      "metadata.travel_end_on",
      "metadata.travel_members",
      "metadata.travel_transport"
    ]
  },
  purchase_request: {
    label: "購買申請",
    summaryHint: "購入の背景や必要性、比較した選択肢があれば記載してください。",
    sections: ["financial", "purchase", "attachments"],
    required: ["summary", "amount", "metadata.purchase_items"],
    fields: [
      "title",
      "summary",
      "additional_information",
      "amount",
      "currency",
      "vendor_name",
      "needed_on",
      "metadata.purchase_items",
      "metadata.purchase_reason",
      "metadata.purchase_supplier",
      "metadata.purchase_expected_on"
    ]
  },
  vehicle_repair: {
    label: "高額修理申請",
    summaryHint: "故障の状況・原因・稼働への影響を記載してください。",
    sections: ["financial", "repair", "attachments"],
    required: ["summary", "metadata.repair_vehicle", "metadata.repair_issue"],
    fields: [
      "title",
      "summary",
      "additional_information",
      "amount",
      "currency",
      "vendor_name",
      "metadata.repair_vehicle",
      "metadata.repair_issue",
      "metadata.repair_estimate_number",
      "metadata.repair_cost_center"
    ]
  },
  challenge_program: {
    label: "チャレンジ制度適用申請",
    summaryHint: "施策の狙いと想定スケジュール、社内連携先を整理してください。",
    sections: ["financial", "challenge", "attachments"],
    required: ["summary", "metadata.challenge_summary"],
    fields: [
      "title",
      "summary",
      "additional_information",
      "amount",
      "currency",
      "metadata.challenge_summary",
      "metadata.challenge_benefit",
      "metadata.challenge_team"
    ]
  },
  asset_transfer: {
    label: "資産移動・売却申請",
    summaryHint: "資産の現状と移動／売却理由、移動先の受け入れ体制を記載してください。",
    sections: ["financial", "asset", "attachments"],
    required: ["summary", "metadata.asset_item"],
    fields: [
      "title",
      "summary",
      "additional_information",
      "metadata.asset_item",
      "metadata.asset_current_location",
      "metadata.asset_new_location",
      "metadata.asset_reason"
    ]
  },
  incident_report: {
    label: "事故申請",
    summaryHint: "発生した事故・インシデントの概要と初動対応を記載してください。",
    sections: ["incident", "attachments"],
    required: ["summary", "metadata.incident_datetime", "metadata.incident_description"],
    fields: [
      "title",
      "summary",
      "additional_information",
      "metadata.incident_datetime",
      "metadata.incident_location",
      "metadata.incident_description",
      "metadata.incident_response",
      "metadata.incident_cost_impact"
    ]
  },
  default: {
    label: "共通テンプレート",
    summaryHint: "申請概要と判断に必要な情報を記載してください。",
    sections: ["financial", "attachments"],
    required: ["summary"],
    fields: ["title", "summary", "additional_information", "amount", "currency", "vendor_name", "needed_on"]
  }
}

export default class extends Controller {
  static targets = [
    "categorySelect",
    "section",
    "field",
    "templateName",
    "summaryHint",
    "summaryInput",
    "addButton"
  ]

  connect() {
    this.changeTemplate()
  }

  changeTemplate() {
    const option = this.categorySelectTarget.selectedOptions[0]
    const code = option ? option.dataset.templateCode || option.dataset.template : option?.value
    const template = TEMPLATES[code] || TEMPLATES.default

    if (this.hasTemplateNameTarget) {
      this.templateNameTarget.textContent = template.label
    }

    if (this.hasSummaryHintTarget) {
      this.summaryHintTarget.textContent = template.summaryHint
    }

    if (this.hasSummaryInputTarget && template.summaryHint) {
      this.summaryInputTarget.placeholder = template.summaryHint
    }

    this.toggleSections(template.sections)
    this.toggleFields(template.fields, template.required)
  }

  toggleSections(activeKeys = []) {
    this.sectionTargets.forEach((section) => {
      const key = section.dataset.sectionKey
      if (!key) return
      const shouldShow = activeKeys.includes(key) || key === "basic"
      section.classList.toggle("d-none", !shouldShow)
    })
  }

  toggleFields(activeFields = [], requiredFields = []) {
    const normalized = activeFields.concat(["category", "title", "summary", "additional_information", "requester_employee_id"])
    const requiredSet = new Set(requiredFields)

    this.fieldTargets.forEach((wrapper) => {
      const name = wrapper.dataset.fieldName
      if (!name) return
      const shouldShow = normalized.includes(name)
      wrapper.classList.toggle("d-none", !shouldShow)
      wrapper.querySelectorAll("input, textarea, select").forEach((input) => {
        const fieldKey = input.name?.includes("metadata") ? `metadata.${input.name.match(/\[metadata\]\[(.+)\]/)?.[1]}` : name
        input.required = shouldShow && requiredSet.has(fieldKey || name)
      })
    })
  }
}
