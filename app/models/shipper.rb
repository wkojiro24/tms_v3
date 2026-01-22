class Shipper < ApplicationRecord
  include TenantScoped

  has_many :destinations, dependent: :nullify
  has_many :tariffs, dependent: :destroy

  validates :code, presence: true, uniqueness: { scope: :tenant_id }
  validates :name, presence: true
end
