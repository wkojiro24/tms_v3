class GradeSalaryTable < ApplicationRecord
  include TenantScoped

  belongs_to :grade_level, optional: true
  has_many :salary_settings, dependent: :nullify

  validates :grade_code, presence: true
  validates :base_salary, presence: true, numericality: { greater_than_or_equal_to: 0 }

  scope :active, -> { where(active: true) }
  scope :effective_on, ->(date) {
    where('effective_from IS NULL OR effective_from <= ?', date)
      .where('effective_until IS NULL OR effective_until >= ?', date)
  }

  def hourly_rate_calculated
    return hourly_rate if hourly_rate.present?
    # 月給から時給を計算（月163.8時間として）
    (base_salary / 163.8).round
  end

  def display_name
    "#{grade_code} - #{grade_name || '等級'} (#{base_salary.to_i.to_fs(:delimited)}円)"
  end
end
