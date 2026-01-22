class SubcontractorCompany < ApplicationRecord
  include TenantScoped

  validates :code, presence: true, uniqueness: { scope: :tenant_id }
  validates :name, presence: true
end
