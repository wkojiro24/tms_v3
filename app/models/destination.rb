class Destination < ApplicationRecord
  include TenantScoped

  belongs_to :shipper, optional: true

  validates :code, presence: true, uniqueness: { scope: :tenant_id }
  validates :name, presence: true
end
