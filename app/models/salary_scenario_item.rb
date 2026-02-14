# frozen_string_literal: true

class SalaryScenarioItem < ApplicationRecord
  # カテゴリ
  CATEGORIES = {
    "base" => "基本給",
    "allowance" => "手当",
    "variable" => "変動給"
  }.freeze

  # 計算タイプ
  CALCULATION_TYPES = {
    "fixed" => "固定金額",
    "hourly" => "時給ベース",
    "formula" => "計算式"
  }.freeze

  belongs_to :salary_scenario

  validates :name, presence: true
  validates :category, inclusion: { in: CATEGORIES.keys, allow_blank: true }
  validates :calculation_type, inclusion: { in: CALCULATION_TYPES.keys }

  scope :ordered, -> { order(:position, :name) }
  scope :base_items, -> { where(category: "base") }
  scope :allowance_items, -> { where(category: "allowance") }
  scope :variable_items, -> { where(category: "variable") }

  def category_label
    CATEGORIES[category] || "未設定"
  end

  def calculation_type_label
    CALCULATION_TYPES[calculation_type] || "固定金額"
  end

  def fixed?
    calculation_type == "fixed"
  end

  def hourly?
    calculation_type == "hourly"
  end
end
