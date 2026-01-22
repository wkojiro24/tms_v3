# 標準報酬月額の定時決定・随時改定を計算するサービス
#
# 定時決定: 毎年4〜6月の報酬平均から9月〜翌年8月の標準報酬月額を決定
# 随時改定: 報酬に大幅な変動があった場合（2等級以上変動が3ヶ月継続）
#
class StandardMonthlyRemunerationCalculator
  attr_reader :tenant, :results

  def initialize(tenant)
    @tenant = tenant
    @results = { calculated: 0, skipped: 0, errors: [] }
  end

  # 全従業員の定時決定を実行
  # @param year [Integer] 対象年度（この年の4-6月を使用）
  # @return [Hash] 結果サマリー
  def calculate_all_for_year(year)
    tenant.employees.active.find_each do |employee|
      calculate_for_employee(employee, year)
    end
    results
  end

  # 単一従業員の定時決定を実行
  # @param employee [Employee] 対象従業員
  # @param year [Integer] 対象年度
  # @return [Integer, nil] 算出された標準報酬月額
  def calculate_for_employee(employee, year)
    # 4〜6月の給与データを取得
    salaries = tenant.salary_monthlies.where(
      employee_code: employee.employee_code,
      year: year,
      month: [4, 5, 6],
      payment_type: 'regular'
    ).order(:month)

    # 3ヶ月分のデータがない場合はスキップ
    if salaries.count < 3
      @results[:skipped] += 1
      @results[:errors] << "#{employee.employee_code}: 4-6月の給与データが不足（#{salaries.count}件）"
      return nil
    end

    # 支払基礎日数をチェック（17日以上の月のみ対象）
    # ※working_daysが支払基礎日数に相当
    valid_months = salaries.select { |s| (s.working_days || 0) >= 17 }

    if valid_months.empty?
      @results[:skipped] += 1
      @results[:errors] << "#{employee.employee_code}: 支払基礎日数17日以上の月がありません"
      return nil
    end

    # 報酬月額の計算
    # 報酬 = 課税支給合計 + 非課税通勤費（= gross_total）
    total_remuneration = valid_months.sum { |s| s.gross_total.to_i }
    average_remuneration = (total_remuneration / valid_months.count.to_f).round

    # 標準報酬月額の等級を決定
    grade = StandardMonthlyRemuneration.health_grade_for(average_remuneration, year: year)
    standard_monthly = grade[1]

    # 給与設定を更新
    setting = tenant.salary_settings
      .for_employee(employee.id)
      .active
      .order(effective_from: :desc)
      .first

    if setting
      # 9月1日から適用
      effective_date = Date.new(year, 9, 1)

      # 既存の設定を更新するか、新しい設定を作成するか判断
      if setting.effective_from >= effective_date
        # 既に9月以降の設定がある場合は更新
        setting.update(standard_monthly_remuneration: standard_monthly)
      else
        # 新しい適用期間の設定を作成
        new_setting = setting.dup
        new_setting.effective_from = effective_date
        new_setting.standard_monthly_remuneration = standard_monthly
        new_setting.save
      end

      @results[:calculated] += 1
    else
      @results[:skipped] += 1
      @results[:errors] << "#{employee.employee_code}: 給与設定がありません"
      return nil
    end

    standard_monthly
  rescue => e
    @results[:errors] << "#{employee.employee_code}: #{e.message}"
    nil
  end

  # 従業員の4-6月データから標準報酬月額を計算（プレビュー用）
  # 給与設定は更新しない
  # @param employee_code [String] 従業員コード
  # @param year [Integer] 対象年度
  # @return [Hash] 計算結果の詳細
  def preview_for_employee(employee_code, year)
    salaries = tenant.salary_monthlies.where(
      employee_code: employee_code,
      year: year,
      month: [4, 5, 6],
      payment_type: 'regular'
    ).order(:month)

    result = {
      employee_code: employee_code,
      year: year,
      months: [],
      valid_months_count: 0,
      average_remuneration: nil,
      standard_monthly: nil,
      health_grade: nil,
      pension_grade: nil,
      status: nil,
      message: nil
    }

    # 各月のデータ
    [4, 5, 6].each do |month|
      salary = salaries.find { |s| s.month == month }
      month_data = {
        month: month,
        gross_total: salary&.gross_total,
        working_days: salary&.working_days,
        valid: salary.present? && (salary.working_days || 0) >= 17
      }
      result[:months] << month_data
    end

    valid_months = result[:months].select { |m| m[:valid] }
    result[:valid_months_count] = valid_months.count

    if valid_months.empty?
      result[:status] = :error
      result[:message] = '支払基礎日数17日以上の月がありません'
      return result
    end

    # 平均報酬月額を計算
    total = valid_months.sum { |m| m[:gross_total].to_i }
    result[:average_remuneration] = (total / valid_months.count.to_f).round

    # 標準報酬月額を決定
    health_grade = StandardMonthlyRemuneration.health_grade_for(result[:average_remuneration], year: year)
    pension_grade = StandardMonthlyRemuneration.pension_grade_for(result[:average_remuneration], year: year)

    result[:standard_monthly] = health_grade[1]
    result[:health_grade] = health_grade[0]
    result[:pension_grade] = pension_grade[0]
    result[:status] = :success
    result[:message] = "#{year}年9月〜#{year + 1}年8月の標準報酬月額"

    # 現在の設定との比較
    employee = tenant.employees.find_by(employee_code: employee_code)
    if employee
      current_setting = tenant.salary_settings
        .for_employee(employee.id)
        .active
        .order(effective_from: :desc)
        .first

      if current_setting&.standard_monthly_remuneration
        current_grade = StandardMonthlyRemuneration.health_grade_for(
          current_setting.standard_monthly_remuneration, year: year
        )
        result[:current_standard_monthly] = current_setting.standard_monthly_remuneration
        result[:current_grade] = current_grade[0]
        result[:grade_change] = result[:health_grade] - result[:current_grade]
      end
    end

    result
  end

  # 随時改定の判定
  # 報酬が2等級以上変動し、3ヶ月継続した場合に改定
  # @param employee_code [String] 従業員コード
  # @param year [Integer] 対象年
  # @param month [Integer] 判定月（この月を含む過去3ヶ月を判定）
  # @return [Hash, nil] 随時改定が必要な場合は詳細、不要な場合はnil
  def check_revision_needed(employee_code, year, month)
    employee = tenant.employees.find_by(employee_code: employee_code)
    return nil unless employee

    current_setting = tenant.salary_settings
      .for_employee(employee.id)
      .active
      .order(effective_from: :desc)
      .first

    return nil unless current_setting&.standard_monthly_remuneration

    # 過去3ヶ月の給与データを取得
    three_months = []
    (0..2).each do |i|
      target_date = Date.new(year, month, 1) - i.months
      three_months << { year: target_date.year, month: target_date.month }
    end

    salaries = tenant.salary_monthlies.where(
      employee_code: employee_code,
      payment_type: 'regular'
    ).where(
      '(year = ? AND month IN (?)) OR (year = ? AND month IN (?))',
      three_months.first[:year], three_months.select { |m| m[:year] == three_months.first[:year] }.map { |m| m[:month] },
      three_months.last[:year], three_months.select { |m| m[:year] == three_months.last[:year] }.map { |m| m[:month] }
    )

    return nil if salaries.count < 3

    # 3ヶ月の平均を計算
    average = (salaries.sum(:gross_total) / 3.0).round
    new_grade = StandardMonthlyRemuneration.health_grade_for(average, year: year)
    current_grade = StandardMonthlyRemuneration.health_grade_for(
      current_setting.standard_monthly_remuneration, year: year
    )

    grade_diff = (new_grade[0] - current_grade[0]).abs

    return nil if grade_diff < 2

    {
      employee_code: employee_code,
      current_standard_monthly: current_setting.standard_monthly_remuneration,
      current_grade: current_grade[0],
      new_standard_monthly: new_grade[1],
      new_grade: new_grade[0],
      grade_change: new_grade[0] - current_grade[0],
      average_remuneration: average,
      effective_from: Date.new(year, month, 1) + 1.month
    }
  end
end
