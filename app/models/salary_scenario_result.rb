# frozen_string_literal: true

class SalaryScenarioResult < ApplicationRecord
  belongs_to :salary_scenario
  belongs_to :employee
  belongs_to :period, optional: true

  validates :employee_id, uniqueness: { scope: :salary_scenario_id }

  scope :ordered, -> { joins(:employee).order("employees.employee_code") }

  # 計算詳細へのアクセスヘルパー
  def details
    @details ||= calculation_details.with_indifferent_access
  end

  # 現行との差額
  def diff_gross
    return 0 unless details[:baseline_gross]

    gross_pay - details[:baseline_gross].to_i
  end

  def diff_net
    return 0 unless details[:baseline_net]

    net_pay - details[:baseline_net].to_i
  end

  # 差額が増加かどうか
  def increased?
    diff_gross.positive?
  end

  def decreased?
    diff_gross.negative?
  end

  # 時給
  def hourly_rate
    details[:hourly_rate].to_i
  end

  # 基準内賃金
  def base_wage
    details[:base_wage].to_i
  end
end
