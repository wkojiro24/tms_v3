# frozen_string_literal: true

class SalaryScenario < ApplicationRecord
  include TenantScoped

  # デフォルトパラメータ
  DEFAULT_PARAMETERS = {
    monthly_hours: 163.8,              # 月平均所定労働時間
    overtime_rate: 1.25,               # 残業割増率（60時間以下）
    overtime_rate_over_60: 1.50,       # 残業割増率（60時間超）
    late_night_rate: 0.25,             # 深夜割増率
    holiday_rate: 1.35,                # 休日割増率
    base_salary_adjustment: 0,         # 基本給調整率（%）
    base_salary_method: "grade_table"  # grade_table, percentage, individual
  }.freeze

  has_many :salary_scenario_items, dependent: :destroy
  has_many :salary_scenario_results, dependent: :destroy

  accepts_nested_attributes_for :salary_scenario_items, allow_destroy: true

  validates :name, presence: true

  scope :ordered, -> { order(created_at: :desc) }

  # パラメータにアクセスするヘルパー
  def monthly_hours
    (parameters["monthly_hours"] || DEFAULT_PARAMETERS[:monthly_hours]).to_f
  end

  def overtime_rate
    (parameters["overtime_rate"] || DEFAULT_PARAMETERS[:overtime_rate]).to_f
  end

  def overtime_rate_over_60
    (parameters["overtime_rate_over_60"] || DEFAULT_PARAMETERS[:overtime_rate_over_60]).to_f
  end

  def late_night_rate
    (parameters["late_night_rate"] || DEFAULT_PARAMETERS[:late_night_rate]).to_f
  end

  def holiday_rate
    (parameters["holiday_rate"] || DEFAULT_PARAMETERS[:holiday_rate]).to_f
  end

  def base_salary_adjustment
    (parameters["base_salary_adjustment"] || 0).to_f
  end

  def base_salary_method
    parameters["base_salary_method"] || "grade_table"
  end

  # パラメータを設定
  def set_default_parameters!
    self.parameters = DEFAULT_PARAMETERS.dup
  end
end
