class SalarySimulation < ApplicationRecord
  include TenantScoped

  belongs_to :employee, optional: true
  belongs_to :attendance_monthly, optional: true
  belongs_to :salary_setting, optional: true

  validates :employee_code, presence: true
  validates :year, presence: true
  validates :month, presence: true

  scope :for_period, ->(year, month) { where(year: year, month: month) }
  scope :for_employee, ->(code) { where(employee_code: code) }

  enum :status, { draft: 'draft', confirmed: 'confirmed', approved: 'approved', error: 'error' }, prefix: true

  def period_label
    "#{year}年#{month}月"
  end

  def has_actual_data?
    actual_gross_total.present? || actual_net_total.present?
  end

  def gross_diff_rate
    return nil unless has_actual_data? && calc_gross_total.to_i > 0
    ((diff_gross.to_f / actual_gross_total) * 100).round(1)
  end

  def net_diff_rate
    return nil unless has_actual_data? && calc_net_total.to_i > 0
    ((diff_net.to_f / actual_net_total) * 100).round(1)
  end

  # 差異が許容範囲内か（5%以内）
  def within_tolerance?(threshold = 5.0)
    return true unless has_actual_data?
    (gross_diff_rate&.abs || 0) <= threshold && (net_diff_rate&.abs || 0) <= threshold
  end
end
