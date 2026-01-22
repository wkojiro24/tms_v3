class Tariff < ApplicationRecord
  include TenantScoped

  belongs_to :shipper, optional: true

  validates :code, presence: true, uniqueness: { scope: :tenant_id }

  scope :effective_on, ->(date) {
    where("effective_from IS NULL OR effective_from <= ?", date)
      .where("effective_until IS NULL OR effective_until >= ?", date)
  }
end
