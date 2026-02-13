class Item < ApplicationRecord
  include TenantScoped

  # 給与グループ定数
  PAYROLL_GROUPS = {
    "base" => "基本給",
    "variable" => "変動給",
    "variable_basis" => "変動給算出根拠",
    "commute" => "通勤費等補助",
    "welfare" => "福利厚生",
    "tax_insurance" => "税金・社会保険",
    "other" => "その他"
  }.freeze

  has_many :item_orders, dependent: :destroy
  has_many :periods, through: :item_orders
  has_many :payroll_cells, dependent: :destroy

  validates :name, presence: true
  validates :name, uniqueness: { scope: [:tenant_id, :above_basic] }
  validates :payroll_group, inclusion: { in: PAYROLL_GROUPS.keys, allow_blank: true }

  scope :alphabetical, -> { order(:name) }
  scope :by_payroll_group, -> { order(Arel.sql("CASE payroll_group WHEN 'base' THEN 1 WHEN 'variable' THEN 2 WHEN 'variable_basis' THEN 3 ELSE 4 END"), :payroll_group_position, :name) }

  def monetary_section?
    above_basic?
  end

  def payroll_group_label
    PAYROLL_GROUPS[payroll_group] || "未設定"
  end

  def base_salary?
    payroll_group == "base"
  end

  def variable_pay?
    payroll_group == "variable"
  end

  def variable_basis?
    payroll_group == "variable_basis"
  end
end
