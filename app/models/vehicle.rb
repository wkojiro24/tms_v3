class Vehicle < ApplicationRecord
  include TenantScoped

  has_many :financial_metrics, class_name: "VehicleFinancialMetric", dependent: :destroy
  has_many_attached :photos
  has_many :vehicle_fault_logs, dependent: :destroy
  has_many :vehicle_inspection_records, dependent: :destroy
  has_many :vehicle_statuses, -> { recent_first }, dependent: :destroy

  scope :ordered, -> { order(:depot_name, :registration_number, :first_registration_on) }
  def display_name
    [registration_number, call_sign].compact.join(" / ")
  end

  def max_load_tons
    return nil if max_load_kg.blank?

    (max_load_kg / 1000.0).round(2)
  end

  validate :photos_within_limit

  private

  def photos_within_limit
    return unless photos.attachments.size > 20

    errors.add(:photos, "は20枚までアップロードできます。")
  end

  public

  def maintenance_status
    vehicle_statuses.first&.status || metadata&.fetch("status", nil) || "active"
  end
end
