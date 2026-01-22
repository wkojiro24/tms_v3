class SalaryMonthly < ApplicationRecord
  include TenantScoped

  belongs_to :employee, optional: true

  validates :employee_code, presence: true
  validates :year, presence: true
  validates :month, presence: true
  validates :payment_type, presence: true

  enum :payment_type, {
    regular: 'regular',
    summer_bonus: 'summer_bonus',
    winter_bonus: 'winter_bonus'
  }, prefix: true

  scope :for_period, ->(year, month) { where(year: year, month: month) }
  scope :for_employee, ->(code) { where(employee_code: code) }
  scope :regular_payments, -> { where(payment_type: 'regular') }
  scope :bonuses, -> { where(payment_type: ['summer_bonus', 'winter_bonus']) }
  scope :for_location, ->(location) { where(location: location) }

  def period_label
    if payment_type_regular?
      "#{year}年#{month}月"
    elsif payment_type_summer_bonus?
      "#{year}年 夏季賞与"
    else
      "#{year}年 冬季賞与"
    end
  end

  def total_deduction_rate
    return 0 if gross_total.to_i.zero?
    (deduction_total.to_f / gross_total * 100).round(1)
  end

  def social_insurance_rate
    return 0 if gross_total.to_i.zero?
    (social_insurance_total.to_f / gross_total * 100).round(1)
  end
end
