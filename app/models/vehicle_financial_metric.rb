class VehicleFinancialMetric < ApplicationRecord
  include TenantScoped

  belongs_to :vehicle, optional: true

  # セル状態
  # value: 実際の値がある（0も含む）
  # blank: 元データが空白だった
  # error: #DIV/0! 等のエラー
  attribute :cell_state, :string, default: "value"
  enum :cell_state, {
    value: "value",
    blank: "blank",
    error: "error"
  }

  scope :for_month, ->(month) { where(month:) }
  scope :for_vehicle_code, ->(code) { where(vehicle_code: code) }
  scope :with_value, -> { where(cell_state: :value) }
  scope :without_blank, -> { where.not(cell_state: :blank) }

  validates :vehicle_code, :metric_key, :metric_label, :month, presence: true
end
