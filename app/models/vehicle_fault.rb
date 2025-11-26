class VehicleFault < ApplicationRecord
  include TenantScoped

  belongs_to :vehicle

  validates :started_on, :summary, presence: true

  scope :current, -> { where(resolved_on: nil) }

  after_commit :sync_vehicle_fault_status

  private

  def sync_vehicle_fault_status
    return unless vehicle.present?

    unresolved_exists = vehicle.vehicle_faults.where(resolved_on: nil).exists?
    new_status = unresolved_exists ? "faulted" : "normal"
    return if vehicle.fault_status == new_status

    vehicle.update!(fault_status: new_status)
  end
end
