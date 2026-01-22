class PlTreeNode < ApplicationRecord
  include TenantScoped
  belongs_to :parent, class_name: "PlTreeNode", optional: true
  has_many :children, class_name: "PlTreeNode", foreign_key: :parent_id, dependent: :destroy
  has_many :pl_mappings, dependent: :destroy
  has_many :snapshots, dependent: :destroy

  enum node_type: {
    normal: "normal",
    calculated: "calculated"
  }

  validates :code, presence: true, uniqueness: { scope: :tenant_id }
  validates :name, presence: true
end
