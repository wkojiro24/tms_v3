class PayrollColumnOrder < ApplicationRecord
  belongs_to :period
  belongs_to :employee

  validates :column_index, presence: true

  default_scope { order(:column_index) }

  scope :for_period, ->(period) { where(period:) }
  scope :for_location, ->(location) { where(location:) }
end
