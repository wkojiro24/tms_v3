class PayrollCell < ApplicationRecord
  belongs_to :period
  belongs_to :employee
  belongs_to :item
  belongs_to :payroll_batch

  validates :period, :employee, :item, presence: true

  scope :for_employee, ->(employee_id) { where(employee_id:) }
  scope :for_period, ->(period_id) { where(period_id:) }
  scope :for_location, ->(location) { where(location:) }
end
