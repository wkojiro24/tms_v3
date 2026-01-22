class VehicleAlias < ApplicationRecord
  include TenantScoped

  enum pattern_type: {
    exact: "exact",
    regex: "regex"
  }

  validates :pattern, presence: true, uniqueness: { scope: :tenant_id }
  validates :vehicle_id, presence: true
end
