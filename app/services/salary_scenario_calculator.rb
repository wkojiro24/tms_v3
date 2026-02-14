# frozen_string_literal: true

# 給与シナリオシミュレーター
# シンプルに基本給・手当・残業代・控除を計算
class SalaryScenarioCalculator
  attr_reader :scenario, :period, :results

  def initialize(scenario, period: nil)
    @scenario = scenario
    @period = period || Period.ordered.first
    @results = { calculated: 0, skipped: 0, errors: [] }
  end

  # 全従業員の試算を実行
  def calculate_all
    employees = Employee.order(:employee_code)

    employees.each do |employee|
      calculate_for(employee)
    end

    results
  end

  # 単一従業員の試算
  def calculate_for(employee)
    # 既存の結果があれば削除して再計算
    result = scenario.salary_scenario_results.find_or_initialize_by(employee: employee)
    result.period = period

    # 勤怠データ取得
    attendance = fetch_attendance(employee)

    # 給与設定取得（現行の基準として）
    setting = fetch_salary_setting(employee)

    # 計算詳細を初期化
    details = {}

    # ===== 基本給計算 =====
    base_salary = calculate_base_salary(employee, setting, details)

    # ===== 時給計算 =====
    base_wage = calculate_base_wage(base_salary, setting, details)
    hourly_rate = (base_wage / scenario.monthly_hours).round
    details[:base_wage] = base_wage
    details[:hourly_rate] = hourly_rate
    details[:monthly_hours] = scenario.monthly_hours

    # ===== 残業代計算 =====
    overtime_pay = calculate_overtime(hourly_rate, attendance, details)
    late_night_pay = calculate_late_night(hourly_rate, attendance, details)
    holiday_pay = calculate_holiday(hourly_rate, attendance, details)

    # ===== 手当計算 =====
    total_allowances = calculate_allowances(employee, setting, details)

    # ===== 総支給額 =====
    gross_pay = base_salary + overtime_pay + late_night_pay + holiday_pay + total_allowances

    # ===== 控除計算 =====
    deductions = calculate_deductions(gross_pay, setting, details)

    # ===== 手取り =====
    net_pay = gross_pay - deductions

    # ===== 現行との比較（ベースライン）=====
    if setting
      details[:baseline_gross] = setting.base_salary.to_i + total_allowances
      details[:baseline_net] = details[:baseline_gross] - deductions
    end

    # 結果を保存
    result.assign_attributes(
      base_salary: base_salary,
      total_allowances: total_allowances,
      overtime_pay: overtime_pay,
      late_night_pay: late_night_pay,
      holiday_pay: holiday_pay,
      gross_pay: gross_pay,
      deductions: deductions,
      net_pay: net_pay,
      calculation_details: details
    )

    if result.save
      @results[:calculated] += 1
    else
      @results[:errors] << "#{employee.employee_code}: #{result.errors.full_messages.join(', ')}"
    end

    result
  rescue => e
    @results[:errors] << "#{employee.employee_code}: #{e.message}"
    @results[:skipped] += 1
    nil
  end

  private

  # 勤怠データ取得
  def fetch_attendance(employee)
    return nil unless period

    AttendanceMonthly.find_by(
      employee_code: employee.employee_code,
      year: period.year,
      month: period.month
    )
  end

  # 給与設定取得
  def fetch_salary_setting(employee)
    SalarySetting.for_employee(employee.id)
                 .active
                 .order(effective_from: :desc)
                 .first
  end

  # 基本給計算
  def calculate_base_salary(employee, setting, details)
    method = scenario.base_salary_method

    case method
    when "grade_table"
      # 等級テーブルから
      base = setting&.base_salary.to_i
    when "percentage"
      # 現行から一定割合増減
      base = setting&.base_salary.to_i
      adjustment = scenario.base_salary_adjustment
      base = (base * (1 + adjustment / 100.0)).round
      details[:base_salary_adjustment] = adjustment
    when "individual"
      # 個別設定（シナリオアイテムから）
      item = scenario.salary_scenario_items.base_items.find_by(name: "基本給")
      base = item&.default_amount.to_i
    else
      base = setting&.base_salary.to_i
    end

    details[:base_salary_method] = method
    details[:base_salary_original] = setting&.base_salary.to_i

    base
  end

  # 基準内賃金計算（時給の基準となる）
  def calculate_base_wage(base_salary, setting, details)
    # 基本給 + 無事故継続加算 + 職位加算 + 職責加算 + 大都市加算
    base_wage = base_salary
    base_wage += setting&.safety_bonus_cumulative.to_i  # 無事故継続加算
    base_wage += setting&.position_allowance.to_i
    base_wage += setting&.role_allowance.to_i
    base_wage += setting&.housing_allowance.to_i  # 大都市加算

    details[:base_wage_breakdown] = {
      base_salary: base_salary,
      safety_bonus_cumulative: setting&.safety_bonus_cumulative.to_i,
      position_allowance: setting&.position_allowance.to_i,
      role_allowance: setting&.role_allowance.to_i,
      housing_allowance: setting&.housing_allowance.to_i
    }

    base_wage
  end

  # 残業代計算
  def calculate_overtime(hourly_rate, attendance, details)
    hours = attendance&.total_overtime.to_f || 0

    # 60時間超の判定
    hours_under_60 = [hours, 60].min
    hours_over_60 = [hours - 60, 0].max

    pay_under_60 = (hourly_rate * hours_under_60 * scenario.overtime_rate).round
    pay_over_60 = (hourly_rate * hours_over_60 * scenario.overtime_rate_over_60).round

    details[:overtime] = {
      hours: hours,
      hours_under_60: hours_under_60,
      hours_over_60: hours_over_60,
      rate_under_60: scenario.overtime_rate,
      rate_over_60: scenario.overtime_rate_over_60,
      pay_under_60: pay_under_60,
      pay_over_60: pay_over_60,
      formula: "時給#{hourly_rate}円 × #{hours_under_60}h × #{scenario.overtime_rate}"
    }

    pay_under_60 + pay_over_60
  end

  # 深夜残業計算
  def calculate_late_night(hourly_rate, attendance, details)
    hours = attendance&.late_night_hours.to_f || 0
    pay = (hourly_rate * hours * scenario.late_night_rate).round

    details[:late_night] = {
      hours: hours,
      rate: scenario.late_night_rate,
      pay: pay,
      formula: "時給#{hourly_rate}円 × #{hours}h × #{scenario.late_night_rate}"
    }

    pay
  end

  # 休日手当計算
  def calculate_holiday(hourly_rate, attendance, details)
    hours = attendance&.holiday_hours.to_f || 0
    pay = (hourly_rate * hours * scenario.holiday_rate).round

    details[:holiday] = {
      hours: hours,
      rate: scenario.holiday_rate,
      pay: pay,
      formula: "時給#{hourly_rate}円 × #{hours}h × #{scenario.holiday_rate}"
    }

    pay
  end

  # 手当計算
  def calculate_allowances(employee, setting, details)
    total = 0
    allowance_details = []

    # シナリオに定義された手当
    scenario.salary_scenario_items.allowance_items.ordered.each do |item|
      amount = item.default_amount.to_i
      total += amount
      allowance_details << { name: item.name, amount: amount }
    end

    # 現行設定からの手当（シナリオに定義がない場合）
    if setting && allowance_details.empty?
      # 無事故加算（月額）
      if setting.safety_bonus.to_i > 0
        total += setting.safety_bonus.to_i
        allowance_details << { name: "無事故加算", amount: setting.safety_bonus.to_i }
      end

      # 調整加算
      if setting.adjustment_allowance.to_i > 0
        total += setting.adjustment_allowance.to_i
        allowance_details << { name: "調整加算", amount: setting.adjustment_allowance.to_i }
      end

      # 家族手当
      if setting.family_allowance.to_i > 0
        total += setting.family_allowance.to_i
        allowance_details << { name: "家族手当", amount: setting.family_allowance.to_i }
      end
    end

    details[:allowances] = allowance_details

    total
  end

  # 控除計算（シンプル版）
  def calculate_deductions(gross_pay, setting, details)
    deduction_details = []
    total = 0

    # 社会保険料（簡易計算）
    if defined?(StandardMonthlyRemuneration) && StandardMonthlyRemuneration.table_exists?
      health_grade = StandardMonthlyRemuneration.health_grade_for(gross_pay, year: period&.year || Date.current.year)
      pension_grade = StandardMonthlyRemuneration.pension_grade_for(gross_pay, year: period&.year || Date.current.year)

      # 健康保険
      health_insurance = (health_grade[1] * 0.04985).round  # 福島県の例
      total += health_insurance
      deduction_details << { name: "健康保険", amount: health_insurance }

      # 厚生年金
      pension = (pension_grade[1] * 0.0915).round
      total += pension
      deduction_details << { name: "厚生年金", amount: pension }

      # 雇用保険
      employment = (gross_pay * 0.006).round
      total += employment
      deduction_details << { name: "雇用保険", amount: employment }

      # 介護保険（40歳以上）
      if setting&.nursing_insurance_applicable?
        nursing = (health_grade[1] * 0.008).round
        total += nursing
        deduction_details << { name: "介護保険", amount: nursing }
      end
    end

    # 所得税（簡易計算）
    taxable_income = gross_pay - total  # 社会保険料控除後
    income_tax = estimate_income_tax(taxable_income, setting&.dependents_count.to_i)
    total += income_tax
    deduction_details << { name: "所得税", amount: income_tax }

    # 住民税（固定）
    if setting&.resident_tax.to_i > 0
      total += setting.resident_tax.to_i
      deduction_details << { name: "住民税", amount: setting.resident_tax.to_i }
    end

    details[:deductions] = deduction_details
    details[:total_deductions] = total

    total
  end

  # 所得税の簡易計算
  def estimate_income_tax(taxable_income, dependents)
    return 0 if taxable_income <= 0

    # 源泉徴収税額の概算（甲欄、扶養人数考慮）
    # 実際にはIncomeTaxTableを使用すべき
    base_rate = case taxable_income
                when 0..88_000 then 0
                when 88_001..89_000 then 130
                when 89_001..300_000 then (taxable_income * 0.03).round
                when 300_001..500_000 then (taxable_income * 0.05).round
                else (taxable_income * 0.1).round
                end

    # 扶養控除
    deduction = dependents * 1580
    [base_rate - deduction, 0].max
  end
end
