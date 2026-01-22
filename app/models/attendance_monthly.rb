class AttendanceMonthly < ApplicationRecord
  include TenantScoped

  belongs_to :employee, optional: true

  validates :employee_code, presence: true
  validates :year, presence: true
  validates :month, presence: true
  validates :employee_code, uniqueness: { scope: [:tenant_id, :year, :month] }

  scope :for_period, ->(year, month) { where(year: year, month: month) }
  scope :for_year, ->(year) { where(year: year) }
  scope :for_employee, ->(code) { where(employee_code: code) }
  scope :ordered, -> { order(:year, :month) }

  def period_label
    "#{year}年#{month}月"
  end

  def actual_working_hours
    (total_hours || 0) - (break_hours || 0)
  end

  def total_overtime
    (overtime_hours || 0) + (holiday_hours || 0) + (extra_holiday_hours || 0) + (late_night_hours || 0)
  end

  def overtime_warning?
    total_overtime > 45
  end

  def overtime_critical?
    total_overtime > 60
  end
end
