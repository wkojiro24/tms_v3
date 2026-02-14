# frozen_string_literal: true

# ドライバー給与比較サービス
# 個人ごとの現行給与と新給与体系の詳細比較を行う
class DriverSalaryComparisonService
  attr_reader :employee, :period, :params

  # 会社負担の社会保険料率
  EMPLOYER_RATES = {
    health_rate: 51.0,          # 健康保険（福島県）
    nursing_rate: 9.0,          # 介護保険
    pension_rate: 91.5,         # 厚生年金
    employment_rate: 9.5,       # 雇用保険（事業主負担）
    workers_comp_rate: 4.5      # 労災保険（運輸業）
  }.freeze

  def initialize(employee:, period:, params:)
    @employee = employee
    @period = period
    @params = params
  end

  # 現行と新給与の詳細比較を実行
  def compare
    setting = current_salary_setting
    return nil unless setting

    location = employee_location
    attendance = employee_attendance
    yearly_avg = yearly_average_attendance

    current = calculate_current_payroll(setting, attendance)
    proposed = calculate_proposed_payroll(setting, attendance, location)

    {
      employee: employee,
      location: location,
      period: period,
      attendance: format_attendance(attendance),
      yearly_average: yearly_avg,
      current: current,
      proposed: proposed,
      diff: {
        gross: proposed[:gross_total] - current[:gross_total],
        net: proposed[:net_total] - current[:net_total],
        company_cost: proposed[:company_cost] - current[:company_cost]
      }
    }
  end

  private

  def current_salary_setting
    SalarySetting.where(employee_id: employee.id)
                 .order(effective_from: :desc)
                 .first
  end

  def employee_location
    cell = PayrollCell.where(period: period, employee: employee).first
    cell&.location || "不明"
  end

  def employee_attendance
    # パラメータで指定されていればそれを使用、なければ過去1年平均を使用
    yearly_avg = yearly_average_attendance

    overtime = if params[:overtime_hours].present?
                 params[:overtime_hours].to_f
               elsif yearly_avg
                 yearly_avg[:overtime_hours]
               else
                 fetch_actual_overtime || 0.0
               end

    late_night = if params[:late_night_hours].present?
                   params[:late_night_hours].to_f
                 elsif yearly_avg
                   yearly_avg[:late_night_hours]
                 else
                   fetch_actual_late_night || 0.0
                 end

    holiday = if params[:holiday_hours].present?
                params[:holiday_hours].to_f
              elsif yearly_avg
                yearly_avg[:holiday_hours]
              else
                fetch_actual_holiday || 0.0
              end

    {
      overtime_hours: overtime,
      late_night_hours: late_night,
      holiday_hours: holiday
    }
  end

  # 実績データから残業時間を取得
  def fetch_actual_overtime
    # PayrollCellから取得を試みる
    overtime_item = Item.find_by(name: "残業時間", payroll_group: "attendance")
    value = get_cell_value(overtime_item)
    return value if value

    # AttendanceMonthlyから取得を試みる
    attendance = AttendanceMonthly.find_by(
      employee_code: employee.employee_code,
      year: period.year,
      month: period.month
    )
    attendance&.total_overtime.to_f
  end

  def fetch_actual_late_night
    late_night_item = Item.find_by(name: "深夜時間", payroll_group: "attendance")
    value = get_cell_value(late_night_item)
    return value if value

    attendance = AttendanceMonthly.find_by(
      employee_code: employee.employee_code,
      year: period.year,
      month: period.month
    )
    attendance&.late_night_hours.to_f
  end

  def fetch_actual_holiday
    holiday_item = Item.find_by(name: "休日時間", payroll_group: "attendance")
    value = get_cell_value(holiday_item)
    return value if value

    attendance = AttendanceMonthly.find_by(
      employee_code: employee.employee_code,
      year: period.year,
      month: period.month
    )
    attendance&.holiday_hours.to_f
  end

  # 過去1年間の平均勤怠データを取得（メモ化）
  def yearly_average_attendance
    return @yearly_average if defined?(@yearly_average)

    # 過去12ヶ月分のデータを取得
    end_date = Date.new(period.year, period.month, 1)
    start_date = end_date - 11.months

    records = AttendanceMonthly.where(employee_code: employee.employee_code)
                               .where("(year * 100 + month) >= ?", start_date.year * 100 + start_date.month)
                               .where("(year * 100 + month) <= ?", end_date.year * 100 + end_date.month)

    @yearly_average = if records.empty?
                        nil
                      else
                        count = records.count
                        {
                          overtime_hours: (records.sum(&:total_overtime).to_f / count).round(1),
                          late_night_hours: (records.sum { |r| r.late_night_hours.to_f } / count).round(1),
                          holiday_hours: (records.sum { |r| r.holiday_hours.to_f } / count).round(1),
                          months_count: count
                        }
                      end
  end

  def get_cell_value(item)
    return nil unless item
    cell = PayrollCell.find_by(period: period, employee: employee, item: item)
    cell&.amount&.to_f
  end

  def format_attendance(attendance)
    {
      overtime_hours: attendance[:overtime_hours],
      late_night_hours: attendance[:late_night_hours],
      holiday_hours: attendance[:holiday_hours]
    }
  end

  # ========== 現行給与計算 ==========

  def calculate_current_payroll(setting, attendance)
    # 固定給
    fixed = calculate_current_fixed(setting)

    # 時給計算
    hourly_rate = calculate_hourly_rate(fixed[:base_wage_total])

    # 変動給（残業代等）
    variable = calculate_variable_pay(hourly_rate, attendance, setting)

    # 総支給額
    gross_total = fixed[:total] + variable[:total]

    # 社会保険・税金
    deductions = calculate_deductions(gross_total, setting)

    # 会社負担
    employer_cost = calculate_employer_cost(gross_total)

    {
      fixed: fixed,
      hourly_rate: hourly_rate,
      variable: variable,
      gross_total: gross_total,
      deductions: deductions,
      net_total: gross_total - deductions[:total],
      employer_cost: employer_cost,
      company_cost: gross_total + employer_cost[:total]
    }
  end

  def calculate_current_fixed(setting)
    # 調整給（PayrollCellから取得）
    adj_item = Item.find_by(name: "調整給", payroll_group: "base")
    adj_cell = PayrollCell.find_by(period: period, employee: employee, item: adj_item)
    adjustment = adj_cell&.amount.to_i

    base_salary = setting.base_salary.to_i
    safety_bonus = setting.safety_bonus.to_i
    position = setting.position_allowance.to_i
    role = setting.role_allowance.to_i
    city = setting.housing_allowance.to_i
    adjustment_allowance = setting.adjustment_allowance.to_i

    # 基準内賃金（時給計算用）
    base_wage_total = base_salary + safety_bonus + position + role + city + adjustment_allowance

    total = base_wage_total + adjustment

    {
      base_salary: base_salary,
      base_salary_label: "基本給",
      safety_bonus: safety_bonus,
      safety_bonus_label: format_safety_label_current(safety_bonus),
      position: position,
      position_label: position > 0 ? "職位加算" : nil,
      role: role,
      role_label: role > 0 ? "職責加算" : nil,
      city: city,
      city_label: city > 0 ? "大都市加算" : nil,
      adjustment: adjustment,
      adjustment_label: adjustment > 0 ? "調整給" : nil,
      adjustment_allowance: adjustment_allowance,
      adjustment_allowance_label: adjustment_allowance > 0 ? "調整加算" : nil,
      difficulty: 0,
      difficulty_label: nil,
      base_wage_total: base_wage_total,
      total: total
    }
  end

  def format_safety_label_current(amount)
    return nil if amount == 0
    "無事故手当"
  end

  # ========== 新給与計算 ==========

  def calculate_proposed_payroll(setting, attendance, location)
    # 固定給
    fixed = calculate_proposed_fixed(setting, location)

    # 時給計算
    hourly_rate = calculate_hourly_rate(fixed[:base_wage_total])

    # 変動給（残業代等）
    variable = calculate_variable_pay(hourly_rate, attendance, setting)

    # 総支給額
    gross_total = fixed[:total] + variable[:total]

    # 社会保険・税金
    deductions = calculate_deductions(gross_total, setting)

    # 会社負担
    employer_cost = calculate_employer_cost(gross_total)

    {
      fixed: fixed,
      hourly_rate: hourly_rate,
      variable: variable,
      gross_total: gross_total,
      deductions: deductions,
      net_total: gross_total - deductions[:total],
      employer_cost: employer_cost,
      company_cost: gross_total + employer_cost[:total]
    }
  end

  def calculate_proposed_fixed(setting, location)
    # 等級（パラメータから取得、なければ現行基本給から推定）
    grade = params[:selected_grade]&.to_i || estimate_grade(setting.base_salary.to_i)
    base_salary = params[:"base_salary_#{grade}"] || default_base_salary(grade)

    # 無事故手当（パラメータから取得）
    safety_status = params[:selected_safety] || estimate_safety_status(setting.safety_bonus.to_i)
    safety_bonus = case safety_status.to_s
                   when "one_year" then params[:safety_one_year] || 10_000
                   when "half_year" then params[:safety_half_year] || 5_000
                   when "accident_once" then params[:safety_half_year] || 5_000
                   else 0
                   end

    # 難易度給（パラメータから取得）
    difficulty_level = params[:selected_difficulty] || "none"
    difficulty = case difficulty_level.to_s
                 when "high" then params[:difficulty_high] || 15_000
                 when "mid" then params[:difficulty_mid] || 10_000
                 when "low" then params[:difficulty_low] || 5_000
                 else 0
                 end

    # 職位・職責（パラメータがあればそれを使用、なければ現行維持）
    position = params[:position_allowance].present? ? params[:position_allowance].to_i : setting.position_allowance.to_i
    role = params[:role_allowance].present? ? params[:role_allowance].to_i : setting.role_allowance.to_i

    # エリア加算
    area = case location
           when "東京", "川崎" then params[:area_tokyo] || 40_000
           when "仙台", "小名浜" then params[:area_sendai] || 10_000
           else 0
           end

    # 基準内賃金（時給計算用）
    base_wage_total = base_salary + safety_bonus + position + role + area + difficulty

    {
      base_salary: base_salary,
      base_salary_label: "基本給（#{grade}級）",
      safety_bonus: safety_bonus,
      safety_bonus_label: format_safety_label_proposed(safety_status),
      position: position,
      position_label: position > 0 ? "職位加算" : nil,
      role: role,
      role_label: role > 0 ? "職責加算" : nil,
      city: 0,
      city_label: nil,
      area: area,
      area_label: area > 0 ? "エリア加算" : nil,
      difficulty: difficulty,
      difficulty_label: format_difficulty_label(difficulty_level),
      adjustment: 0,
      adjustment_label: nil,
      adjustment_allowance: 0,
      adjustment_allowance_label: nil,
      base_wage_total: base_wage_total,
      total: base_wage_total,
      selected_grade: grade,
      selected_safety: safety_status,
      selected_difficulty: difficulty_level
    }
  end

  def estimate_grade(current_base)
    case current_base
    when 0..184_999 then 1
    when 185_000..194_999 then 2
    when 195_000..204_999 then 3
    when 205_000..214_999 then 4
    else 5
    end
  end

  def default_base_salary(grade)
    [180_000, 190_000, 200_000, 210_000, 220_000][grade - 1] || 200_000
  end

  def estimate_safety_status(current_safety)
    return "none" if current_safety == 0
    current_safety >= 5000 ? "one_year" : "half_year"
  end

  def format_safety_label_proposed(status)
    case status.to_s
    when "one_year" then "無事故手当（1年）"
    when "half_year" then "無事故手当（半年）"
    when "accident_once" then "無事故手当（事故1回後）"
    else nil
    end
  end

  def format_difficulty_label(level)
    case level.to_s
    when "high" then "難易度給（高）"
    when "mid" then "難易度給（中）"
    when "low" then "難易度給（低）"
    else nil
    end
  end

  # ========== 共通計算 ==========

  def calculate_hourly_rate(base_wage)
    (base_wage / 163.8).round
  end

  def calculate_variable_pay(hourly_rate, attendance, setting)
    overtime_rate = setting.overtime_rate || 1.25
    late_night_rate = setting.late_night_rate || 0.25
    holiday_rate = setting.holiday_rate || 1.35

    overtime_pay = (attendance[:overtime_hours] * hourly_rate * overtime_rate).round
    late_night_pay = (attendance[:late_night_hours] * hourly_rate * late_night_rate).round
    holiday_pay = (attendance[:holiday_hours] * hourly_rate * holiday_rate).round

    {
      overtime_pay: overtime_pay,
      overtime_hours: attendance[:overtime_hours],
      overtime_rate: overtime_rate,
      late_night_pay: late_night_pay,
      late_night_hours: attendance[:late_night_hours],
      late_night_rate: late_night_rate,
      holiday_pay: holiday_pay,
      holiday_hours: attendance[:holiday_hours],
      holiday_rate: holiday_rate,
      total: overtime_pay + late_night_pay + holiday_pay
    }
  end

  def calculate_deductions(gross_total, setting)
    # 社会保険料計算
    insurance = StandardMonthlyRemuneration.calculate_all(
      gross_total,
      include_nursing: setting.nursing_insurance_applicable?,
      year: period.year,
      prefecture: '福島'
    )

    # 所得税（簡易計算）
    taxable = gross_total - insurance[:health_insurance] - insurance[:nursing_insurance] -
              insurance[:pension_insurance] - insurance[:employment_insurance]
    income_tax = calculate_income_tax(taxable, setting.dependents_count.to_i)

    # 住民税
    resident_tax = setting.resident_tax.to_i

    {
      health_insurance: insurance[:health_insurance],
      nursing_insurance: insurance[:nursing_insurance],
      pension_insurance: insurance[:pension_insurance],
      employment_insurance: insurance[:employment_insurance],
      income_tax: income_tax,
      resident_tax: resident_tax,
      total: insurance[:health_insurance] + insurance[:nursing_insurance] +
             insurance[:pension_insurance] + insurance[:employment_insurance] +
             income_tax + resident_tax
    }
  end

  def calculate_income_tax(taxable_amount, dependents_count)
    # 簡易所得税計算（源泉徴収税額表を使用）
    if defined?(IncomeTaxTable)
      IncomeTaxTable.lookup(taxable_amount, dependents: dependents_count, table_type: 'A')
    else
      # フォールバック：概算計算
      rate = case taxable_amount
             when 0..88_000 then 0
             when 88_001..162_500 then 0.05
             when 162_501..275_000 then 0.10
             else 0.20
             end
      (taxable_amount * rate).round
    end
  end

  def calculate_employer_cost(gross_total)
    # 健康保険の標準報酬月額を取得
    health_grade = StandardMonthlyRemuneration.health_grade_for(gross_total)
    health_standard = health_grade[1]

    # 厚生年金の標準報酬月額を取得
    pension_grade = StandardMonthlyRemuneration.pension_grade_for(gross_total)
    pension_standard = pension_grade[1]

    health = (health_standard * EMPLOYER_RATES[:health_rate] / 1000).round
    nursing = (health_standard * EMPLOYER_RATES[:nursing_rate] / 1000).round
    pension = (pension_standard * EMPLOYER_RATES[:pension_rate] / 1000).round
    employment = (gross_total * EMPLOYER_RATES[:employment_rate] / 1000).round
    workers_comp = (gross_total * EMPLOYER_RATES[:workers_comp_rate] / 1000).round

    {
      health_insurance: health,
      nursing_insurance: nursing,
      pension_insurance: pension,
      employment_insurance: employment,
      workers_comp_insurance: workers_comp,
      total: health + nursing + pension + employment + workers_comp
    }
  end
end
