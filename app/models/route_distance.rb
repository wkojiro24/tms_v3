class RouteDistance < ApplicationRecord
  include TenantScoped

  validates :origin_code, presence: true
  validates :destination_code, presence: true
  validates :origin_code, uniqueness: { scope: [:tenant_id, :destination_code] }
end
