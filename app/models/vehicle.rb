class Vehicle < ApplicationRecord
  include TenantScoped

  belongs_to :default_employee, class_name: "Employee", optional: true

  has_many :financial_metrics, class_name: "VehicleFinancialMetric", dependent: :destroy
  has_many_attached :photos
  has_many :vehicle_fault_logs, dependent: :destroy
  has_many :vehicle_faults, dependent: :destroy
  has_many :vehicle_inspection_records, dependent: :destroy
  has_many :vehicle_statuses, -> { recent_first }, dependent: :destroy
  has_many :maintenance_events, primary_key: :registration_number, foreign_key: :vehicle_number, dependent: :destroy
  has_many :vehicle_cargo_bindings, dependent: :destroy
  has_many :transport_orders, dependent: :nullify

  enum :fault_status, { normal: 0, faulted: 1, suspended: 1, reduced: 2 }, prefix: true

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

  def suspended?
    maintenance_status == "休車" || fault_status_suspended?
  end

  def current_fault
    vehicle_faults.current.order(started_on: :desc).first
  end

  def faulted?
    fault_status_faulted? || fault_status_suspended?
  end

  def reduced?
    fault_status_reduced?
  end

  def default_cargo_binding
    vehicle_cargo_bindings.default_bindings.ordered.first
  end

  def default_cargo_name
    default_cargo_binding&.cargo_name
  end
end
