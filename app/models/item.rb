class Item < ApplicationRecord
  include TenantScoped

  # 給与グループ定数（給与明細の流れに沿った順序）
  PAYROLL_GROUPS = {
    "base" => "基本給",
    "allowance" => "手当等",
    "variable_basis" => "勤怠実績",
    "variable" => "変動給",
    "taxable_subtotal" => "課税支給",
    "commute" => "通勤費等（非課税）",
    "gross_total" => "総支給",
    "welfare" => "福利厚生",
    "tax_insurance" => "社会保険・税金",
    "deduction_total" => "控除計",
    "net_pay" => "差引支給",
    "reference" => "参考情報",
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
