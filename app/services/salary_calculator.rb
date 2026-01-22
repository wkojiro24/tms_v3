class SalaryCalculator
  attr_reader :tenant, :year, :month, :results

  def initialize(tenant, year:, month:)
    @tenant = tenant
    @year = year
    @month = month
    @results = { calculated: 0, skipped: 0, errors: [] }
  end

  # 全従業員の給与シミュレーションを実行
  def calculate_all
    attendance_data = tenant.attendance_monthlies.for_period(year, month)

    attendance_data.each do |attendance|
      calculate_for_employee(attendance)
    end

    results
  end

  # 単一従業員の給与シミュレーション
  def calculate_for_employee(attendance)
    employee = tenant.employees.find_by(employee_code: attendance.employee_code)

    # 給与設定を取得
    setting = find_salary_setting(employee, attendance.employee_code)

    unless setting
      @results[:skipped] += 1
      @results[:errors] << "#{attendance.employee_code}: 給与設定がありません"
      return nil
    end

    # シミュレーション結果を作成/更新
    simulation = tenant.salary_simulations.find_or_initialize_by(
      employee_code: attendance.employee_code,
      year: year,
      month: month
    )

    simulation.employee = employee
    simulation.attendance_monthly = attendance
    simulation.salary_setting = setting

    # 勤怠データをセット
    simulation.working_days = attendance.working_days
    simulation.overtime_hours = attendance.total_overtime
    simulation.late_night_hours = attendance.late_night_hours
    simulation.holiday_hours = attendance.holiday_hours
    simulation.paid_leave_days = attendance.paid_leave_days

    # 給与計算実行
    calculate_payment(simulation, setting, attendance)
    calculate_deduction(simulation, setting)
    calculate_totals(simulation)
    compare_with_actual(simulation)

    if simulation.save
      @results[:calculated] += 1
    else
      @results[:errors] << "#{attendance.employee_code}: #{simulation.errors.full_messages.join(', ')}"
    end

    simulation
  rescue => e
    @results[:errors] << "#{attendance.employee_code}: #{e.message}"
    nil
  end

  private

  def find_salary_setting(employee, employee_code)
    return nil unless employee

    target_date = Date.new(year, month, 1)
    tenant.salary_settings
      .for_employee(employee.id)
      .effective_on(target_date)
      .active
      .order(effective_from: :desc)
      .first
  end

  def calculate_payment(simulation, setting, attendance)
    # ===== すべて計算で算出する（実績データには依存しない） =====

    # 基本給（等級テーブルまたは個別設定）
    simulation.calc_basic_salary = setting.base_salary

    # 時給計算
    hourly_rate = setting.hourly_rate

    # 残業手当: 残業時間 × 時給 × 割増率(1.25)
    overtime_hours = attendance.overtime_hours.to_f
    overtime_unit_rate = (hourly_rate * setting.overtime_rate).round
    simulation.calc_overtime_pay = (overtime_hours * overtime_unit_rate).round

    # 深夜加算: 深夜時間 × 時給 × 深夜割増率(0.25)
    late_night_hours = attendance.late_night_hours.to_f
    late_night_unit_rate = (hourly_rate * setting.late_night_rate).round
    simulation.calc_late_night_pay = (late_night_hours * late_night_unit_rate).round

    # 休日手当: 法定休日時間 × 時給 × 休日割増率(1.35)
    legal_holiday_hours = attendance.holiday_hours.to_f
    extra_holiday_hours = attendance.extra_holiday_hours.to_f
    holiday_unit_rate = (hourly_rate * setting.holiday_rate).round
    statutory_pay = (legal_holiday_hours * holiday_unit_rate).round
    non_statutory_pay = (extra_holiday_hours * holiday_unit_rate).round
    simulation.calc_holiday_pay = statutory_pay + non_statutory_pay

    # 代休残業手当: 代休時間 × 時給 × 割増加算分(0.35)
    # 代休を取得した場合、休日出勤分は既に1.0倍で支払済み
    # 代休残業として支払うのは割増分（休日割増率 - 1.0）のみ
    substitute_holiday_hours = attendance.substitute_holiday_hours.to_f
    substitute_premium_rate = setting.holiday_rate - 1.0  # 1.35 - 1.0 = 0.35
    substitute_unit_rate = (hourly_rate * substitute_premium_rate).round
    substitute_pay = (substitute_holiday_hours * substitute_unit_rate).round
    simulation.calc_substitute_holiday_pay = substitute_pay

    # 有給休暇手当
    paid_leave_days = attendance.paid_leave_days.to_f
    if setting.salary_type == 'monthly'
      # 月給制: 有給手当は計上しない（基本給に含まれる）
      simulation.calc_paid_leave_pay = 0
    else
      # 日給制・時給制: 有給日数 × 日給（8時間分）
      daily_rate = hourly_rate * 8
      simulation.calc_paid_leave_pay = (paid_leave_days * daily_rate).round
    end

    # 通勤手当（非課税）
    if setting.commuting_distance.to_f > 0
      # 距離計算: 賃金規則第23条
      working_days_for_commute = attendance.working_days.to_f
      fuel_price = tenant.fuel_price.to_f > 0 ? tenant.fuel_price.to_f : 160.0
      fuel_efficiency = setting.fuel_efficiency.to_f > 0 ? setting.fuel_efficiency.to_f : 13.0
      simulation.calc_commuting_allowance = (setting.commuting_distance.to_f * fuel_price / fuel_efficiency * 2 * working_days_for_commute).round
    elsif setting.commuting_daily_rate.to_i > 0
      # 日額指定がある場合
      working_days_for_commute = attendance.working_days.to_f
      simulation.calc_commuting_allowance = (setting.commuting_daily_rate * working_days_for_commute).round
    else
      # 月額固定
      simulation.calc_commuting_allowance = setting.commuting_allowance.to_i
    end

    # その他手当（大都市加算、職位加算、職責加算、家族手当、調整給、調整加算、基本給2、役員報酬）
    city_allowance = setting.housing_allowance.to_i        # 大都市加算
    position_allowance = setting.position_allowance.to_i  # 職位加算
    role_allowance = setting.role_allowance.to_i          # 職責加算
    family_allowance = setting.family_allowance.to_i      # 家族手当
    adjustment_salary = setting.adjustment_salary.to_i    # 調整給
    adjustment_allowance = setting.adjustment_allowance.to_i  # 調整加算
    basic_salary_2 = setting.basic_salary_2.to_i          # 基本給2
    executive_salary = setting.executive_salary.to_i      # 役員報酬
    absence_deduction = setting.absence_deduction.to_i    # 欠勤控除

    safety_bonus = setting.safety_bonus.to_i

    simulation.calc_other_allowances = city_allowance +
                                       position_allowance +
                                       role_allowance +
                                       family_allowance +
                                       adjustment_salary +
                                       adjustment_allowance +
                                       basic_salary_2 +
                                       executive_salary +
                                       absence_deduction  # 通常はマイナス値

    # 無事故加算を別途保存
    simulation.calc_safety_bonus = safety_bonus

    # 支給合計
    simulation.calc_gross_total = simulation.calc_basic_salary.to_i +
                                  simulation.calc_overtime_pay.to_i +
                                  simulation.calc_late_night_pay.to_i +
                                  simulation.calc_holiday_pay.to_i +
                                  simulation.calc_substitute_holiday_pay.to_i +
                                  simulation.calc_paid_leave_pay.to_i +
                                  simulation.calc_commuting_allowance.to_i +
                                  simulation.calc_other_allowances.to_i +
                                  simulation.calc_safety_bonus.to_i

    # 計算詳細を保存
    simulation.calculation_details ||= {}
    simulation.calculation_details['payment'] = {
      hourly_rate: hourly_rate,
      overtime_rate: setting.overtime_rate,
      late_night_rate: setting.late_night_rate,
      holiday_rate: setting.holiday_rate,
      overtime_hours: overtime_hours,
      late_night_hours: late_night_hours,
      legal_holiday_hours: legal_holiday_hours,
      extra_holiday_hours: extra_holiday_hours,
      statutory_holiday_pay: statutory_pay,
      non_statutory_holiday_pay: non_statutory_pay,
      substitute_holiday_hours: substitute_holiday_hours,
      substitute_holiday_pay: substitute_pay,
      paid_leave_days: paid_leave_days,
      city_allowance: city_allowance,
      position_allowance: position_allowance,
      role_allowance: role_allowance,
      family_allowance: family_allowance,
      adjustment_salary: adjustment_salary,
      adjustment_allowance: adjustment_allowance,
      basic_salary_2: basic_salary_2,
      executive_salary: executive_salary,
      absence_deduction: absence_deduction,
      safety_bonus: safety_bonus,
    }
  end

  def calculate_deduction(simulation, setting)
    # ===== すべて計算で算出する（実績データには依存しない） =====

    # 標準報酬月額の決定
    # 1. 給与設定に登録されている場合はそれを使用（定時決定・随時改定の結果）
    # 2. 未登録の場合は支給合計から推定
    if setting.standard_monthly_remuneration.present?
      # 固定の標準報酬月額を使用
      standard_monthly = setting.standard_monthly_remuneration
      health_grade = StandardMonthlyRemuneration.health_grade_for(standard_monthly, year: year)
      pension_grade = StandardMonthlyRemuneration.pension_grade_for(standard_monthly, year: year)
    else
      # 支給合計から等級を推定
      monthly_remuneration = simulation.calc_gross_total
      health_grade = StandardMonthlyRemuneration.health_grade_for(monthly_remuneration, year: year)
      pension_grade = StandardMonthlyRemuneration.pension_grade_for(monthly_remuneration, year: year)
    end

    health_standard = health_grade[1]
    pension_standard = pension_grade[1]

    # 介護保険の対象判定（40歳以上65歳未満）
    include_nursing = setting.nursing_insurance_applicable?

    # 標準報酬月額に基づいて社会保険料を計算
    # 都道府県（tenantに設定があれば使用、なければデフォルト）
    prefecture = tenant.respond_to?(:prefecture) ? (tenant.prefecture || '福島') : '福島'

    health_result = StandardMonthlyRemuneration.calculate_health_insurance(
      health_standard,
      include_nursing: include_nursing,
      year: year,
      prefecture: prefecture
    )

    insurance = {
      health_insurance: health_result[:health],
      nursing_insurance: health_result[:nursing],
      pension_insurance: StandardMonthlyRemuneration.calculate_pension(pension_standard, year: year),
      employment_insurance: StandardMonthlyRemuneration.calculate_employment_insurance(simulation.calc_gross_total, year: year),
      health_standard_monthly: health_standard,
      pension_standard_monthly: pension_standard,
      health_grade: health_grade[0],
      pension_grade: pension_grade[0]
    }

    simulation.calc_health_insurance = insurance[:health_insurance]
    simulation.calc_nursing_insurance = insurance[:nursing_insurance]
    simulation.calc_pension = insurance[:pension_insurance]
    simulation.calc_employment_insurance = insurance[:employment_insurance]

    social_insurance_total = simulation.calc_health_insurance +
                             simulation.calc_nursing_insurance +
                             simulation.calc_pension +
                             simulation.calc_employment_insurance

    # 課税所得 = 支給合計 - 通勤手当（非課税）
    taxable_income = simulation.calc_gross_total - simulation.calc_commuting_allowance.to_i

    # 所得税計算（課税所得 - 社会保険料）
    taxable_for_income_tax = taxable_income - social_insurance_total
    simulation.calc_income_tax = calculate_income_tax(taxable_for_income_tax, setting.dependents_count)

    # 組合費・住民税は給与設定から取得
    simulation.calc_union_fee = setting.union_fee.to_i
    simulation.calc_resident_tax = setting.resident_tax.to_i

    # 控除合計 = 社会保険料 + 所得税 + 住民税 + 組合費
    simulation.calc_deduction_total = simulation.calc_health_insurance.to_i +
                                      simulation.calc_nursing_insurance.to_i +
                                      simulation.calc_pension.to_i +
                                      simulation.calc_employment_insurance.to_i +
                                      simulation.calc_income_tax.to_i +
                                      simulation.calc_union_fee.to_i +
                                      simulation.calc_resident_tax.to_i

    # 計算詳細を保存
    simulation.calculation_details ||= {}
    simulation.calculation_details['deduction'] = {
      monthly_remuneration: monthly_remuneration,
      health_standard_monthly: insurance[:health_standard_monthly],
      pension_standard_monthly: insurance[:pension_standard_monthly],
      health_grade: insurance[:health_grade],
      pension_grade: insurance[:pension_grade],
      include_nursing: include_nursing
    }
  end

  def calculate_totals(simulation)
    simulation.calc_net_total = simulation.calc_gross_total - simulation.calc_deduction_total
  end

  def compare_with_actual(simulation)
    # 実際の給与データを取得
    actual = tenant.salary_monthlies.find_by(
      employee_code: simulation.employee_code,
      year: year,
      month: month,
      payment_type: 'regular'
    )

    if actual
      simulation.actual_gross_total = actual.gross_total
      simulation.actual_net_total = actual.net_total
      simulation.diff_gross = simulation.calc_gross_total - actual.gross_total.to_i
      simulation.diff_net = simulation.calc_net_total - actual.net_total.to_i
      simulation.status = simulation.within_tolerance? ? 'confirmed' : 'draft'
    else
      simulation.status = 'draft'
    end
  end

  # 所得税計算（源泉徴収税額表を使用）
  def calculate_income_tax(taxable_amount, dependents_count)
    IncomeTaxTable.lookup(taxable_amount, dependents: dependents_count, table_type: 'A')
  end
end
