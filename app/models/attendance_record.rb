class AttendanceRecord < ApplicationRecord
  include TenantScoped

  belongs_to :employee, optional: true

  validates :employee_code, presence: true
  validates :work_date, presence: true
  validates :employee_code, uniqueness: { scope: [:tenant_id, :work_date] }

  scope :for_period, ->(start_date, end_date) { where(work_date: start_date..end_date) }
  scope :for_employee, ->(code) { where(employee_code: code) }
  scope :ordered, -> { order(:work_date) }

  DAY_TYPES = {
    'weekday' => '平日',
    'holiday' => '法定休日',
    'extra_holiday' => '法定外休日'
  }.freeze

  def worked?
    clock_in.present? && clock_out.present?
  end

  def working_hours
    return 0 unless worked?
    hours = ((clock_out - clock_in) / 3600.0).round(2)
    hours - (break_hours || 0)
  end

  def day_type_label
    day_type
  end
end
