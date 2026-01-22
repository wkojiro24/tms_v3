class PlMapping < ApplicationRecord
  include TenantScoped
  belongs_to :pl_tree_node

  enum mapping_scope: {
    company: "company",
    department: "department",
    vehicle: "vehicle"
  }

  scope :active, -> { where(active: true) }

  validates :priority, numericality: { greater_than_or_equal_to: 0 }
  validates :mapping_scope, presence: true
end
