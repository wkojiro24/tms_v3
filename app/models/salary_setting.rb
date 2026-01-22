class SalarySetting < ApplicationRecord
  include TenantScoped

  belongs_to :employee
  belongs_to :grade_salary_table, optional: true
  has_many :salary_simulations, dependent: :nullify

  validates :employee_id, presence: true
  validates :effective_from, presence: true
  validates :salary_type, presence: true, inclusion: { in: %w[monthly daily hourly] }

  scope :active, -> { where(active: true) }
  scope :effective_on, ->(date) {
    where('effective_from <= ?', date)
      .where('effective_until IS NULL OR effective_until >= ?', date)
  }
  scope :for_employee, ->(employee_id) { where(employee_id: employee_id) }

  def base_salary
    base_salary_override.presence || grade_salary_table&.base_salary || 0
  end

  def city_allowance
    grade_salary_table&.city_allowance || 0
  end

  # 月平均所定労働時間: 163.8時間
  # 優先順位:
  # 1. hourly_rate_override（個別設定）
  # 2. grade_salary_table.hourly_rate（等級テーブル設定）
  # 3. 計算: 時給計算基礎 / 163.8（端数四捨五入）
  def hourly_rate
    return hourly_rate_override if hourly_rate_override.present?
    return grade_salary_table.hourly_rate if grade_salary_table&.hourly_rate.present?
    (hourly_rate_base / 163.8).round
  end

  # 時給計算の基礎となる金額（基準内賃金）
  # 賃金規則第２章: 基準内賃金 = 基本給 + 調整加算 + 無事故継続加算累計 + 職位加算 + 職責加算 + 大都市勤務加算
  # ※家族手当・通勤手当・無事故報奨金（チャレンジ）は基準外賃金
  def hourly_rate_base
    base_salary +
      adjustment_allowance.to_i +    # 調整加算（第15条）
      safety_bonus_cumulative.to_i + # 無事故継続加算累計（第16条）
      position_allowance.to_i +      # 職位加算（第18条）
      role_allowance.to_i +          # 職責加算（第19条）
      housing_allowance.to_i         # 大都市勤務加算（第20条）
  end

  def overtime_rate
    grade_salary_table&.overtime_rate || 1.25
  end

  def late_night_rate
    grade_salary_table&.late_night_rate || 0.25
  end

  def holiday_rate
    grade_salary_table&.holiday_rate || 1.35
  end

  def total_fixed_allowances
    commuting_allowance.to_i +
    family_allowance.to_i +
    housing_allowance.to_i +
    position_allowance.to_i +
    qualification_allowance.to_i
  end

  # 介護保険対象者判定（40歳以上65歳未満）
  # 手動設定または従業員の生年月日から判定
  def nursing_insurance_applicable?
    # 手動設定がある場合はそれを使用
    return nursing_insurance_flag unless nursing_insurance_flag.nil?

    # 従業員の生年月日から判定（birth_dateカラムがある場合のみ）
    if employee.respond_to?(:birth_date) && employee&.birth_date.present?
      age = calculate_age(employee.birth_date)
      age >= 40 && age < 65
    else
      # デフォルトは対象（40歳以上と仮定）
      true
    end
  end

  private

  def calculate_age(birth_date)
    today = Date.current
    age = today.year - birth_date.year
    age -= 1 if today < birth_date + age.years
    age
  end
end
