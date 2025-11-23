class VehicleFinancialMetric < ApplicationRecord
  include TenantScoped

  belongs_to :vehicle, optional: true

  scope :for_month, ->(month) { where(month:) }
  scope :for_vehicle_code, ->(code) { where(vehicle_code: code) }

  validates :vehicle_code, :metric_key, :metric_label, :month, presence: true
end
