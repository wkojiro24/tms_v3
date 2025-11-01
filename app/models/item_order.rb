class ItemOrder < ApplicationRecord
  include TenantScoped

  belongs_to :period
  belongs_to :item

  validates :row_index, presence: true

  default_scope { order(:row_index) }

  scope :for_location, ->(location) { where(location:) }
end
