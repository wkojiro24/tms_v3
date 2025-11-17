class Vehicle < ApplicationRecord
  include TenantScoped

  has_many :financial_metrics, class_name: "VehicleFinancialMetric", dependent: :destroy

  scope :ordered, -> { order(:depot_name, :registration_number, :first_registration_on) }
  def display_name
    [registration_number, call_sign].compact.join(" / ")
  end

  def max_load_tons
    return nil if max_load_kg.blank?

    (max_load_kg / 1000.0).round(2)
  end
end
