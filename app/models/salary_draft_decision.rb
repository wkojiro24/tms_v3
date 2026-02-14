# frozen_string_literal: true

# 給与仮決め
# 新給与体系のシミュレーション結果を個人ごとに仮保存
class SalaryDraftDecision < ApplicationRecord
  belongs_to :employee
  belongs_to :period

  validates :employee_id, uniqueness: { scope: :period_id, message: "この期間の仮決めは既に存在します" }

  scope :ordered, -> { joins(:employee).order("employees.employee_code") }
  scope :for_period, ->(period) { where(period: period) }

  # 総人件費差額
  def self.total_company_cost_diff(period = nil)
    scope = period ? for_period(period) : all
    scope.sum(:diff_company_cost)
  end

  # 従業員の手取り差額合計
  def self.total_net_diff(period = nil)
    scope = period ? for_period(period) : all
    scope.sum(:diff_net)
  end

  # 等級ラベル
  def grade_label
    "#{selected_grade}級" if selected_grade.present?
  end

  # 無事故手当ラベル
  def safety_label
    case selected_safety
    when "one_year" then "1年"
    when "half_year" then "半年"
    when "accident_once" then "事故1回後"
    else "なし"
    end
  end

  # 難易度ラベル
  def difficulty_label
    case selected_difficulty
    when "high" then "高"
    when "mid" then "中"
    when "low" then "低"
    else "なし"
    end
  end
end
