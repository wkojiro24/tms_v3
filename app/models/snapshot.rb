class Snapshot < ApplicationRecord
  include TenantScoped
  belongs_to :pl_tree_node

  enum scope_type: {
    company: "company",
    department: "department",
    vehicle: "vehicle"
  }

  validates :period_month, presence: true
  validates :scope_type, presence: true
  validates :scope_key, presence: true
end
