module Admin
  class PayrollSimulationsController < BaseController
    def index
      @year = params[:year]&.to_i || Date.current.year
      @month = params[:month]&.to_i || Date.current.month

      @simulations = current_tenant.salary_simulations
        .for_period(@year, @month)
        .includes(:employee, :salary_setting)
        .order(:employee_code)

      @attendances = current_tenant.attendance_monthlies.for_period(@year, @month)

      # サマリー
      # with_diff: 許容範囲(5%)を超える差異がある件数（within_tolerance? = false）
      # これはstatusがdraftのままの件数と一致する
      @summary = {
        total_employees: @attendances.count,
        simulated: @simulations.count,
        confirmed: @simulations.where(status: ['confirmed', 'approved']).count,
        with_diff: @simulations.where(status: 'draft').where.not(diff_gross: nil).count,
        total_calc_gross: @simulations.sum(:calc_gross_total),
        total_calc_net: @simulations.sum(:calc_net_total),
        total_actual_gross: @simulations.sum(:actual_gross_total),
        total_actual_net: @simulations.sum(:actual_net_total)
      }

      # 利用可能な年月リスト
      @available_periods = current_tenant.attendance_monthlies
        .select(:year, :month)
        .distinct
        .order(year: :desc, month: :desc)
        .map { |a| [a.year, a.month] }
    end

    def show
      @simulation = current_tenant.salary_simulations.find(params[:id])
      @attendance = @simulation.attendance_monthly
      @setting = @simulation.salary_setting
      @actual_salary = current_tenant.salary_monthlies.find_by(
        employee_code: @simulation.employee_code,
        year: @simulation.year,
        month: @simulation.month,
        payment_type: 'regular'
      )
    end

    def edit
      @simulation = current_tenant.salary_simulations.find(params[:id])
      @setting = @simulation.salary_setting
    end

    def update
      @simulation = current_tenant.salary_simulations.find(params[:id])

      if @simulation.update(simulation_params)
        # 支給合計・控除合計・差引支給額を再計算
        recalculate_totals(@simulation)
        @simulation.save

        flash[:notice] = "給与計算を更新しました。"
        redirect_to admin_payroll_simulation_path(@simulation)
      else
        @setting = @simulation.salary_setting
        render :edit
      end
    end

    def calculate
      @year = params[:year]&.to_i || Date.current.year
      @month = params[:month]&.to_i || Date.current.month

      calculator = SalaryCalculator.new(current_tenant, year: @year, month: @month)
      results = calculator.calculate_all

      if results[:errors].any? && results[:calculated] == 0
        flash[:alert] = "計算エラー: #{results[:errors].first(3).join(', ')}"
      elsif results[:errors].any?
        flash[:warning] = "#{results[:calculated]}件計算完了（#{results[:skipped]}件スキップ、#{results[:errors].size}件エラー）"
      else
        flash[:notice] = "#{results[:calculated]}件の給与シミュレーションを計算しました。"
      end

      redirect_to admin_payroll_simulations_path(year: @year, month: @month)
    end

    # 個別承認
    def approve
      @simulation = current_tenant.salary_simulations.find(params[:id])
      @simulation.update!(
        status: 'approved',
        approved_at: Time.current,
        approved_by_id: current_user.id,
        approval_note: params[:note]
      )
      flash[:notice] = "#{@simulation.employee&.full_name || @simulation.employee_code}の給与を承認しました。"
      redirect_to admin_payroll_simulation_path(@simulation)
    end

    # 承認取消
    def unapprove
      @simulation = current_tenant.salary_simulations.find(params[:id])
      @simulation.update!(
        status: 'draft',
        approved_at: nil,
        approved_by_id: nil,
        approval_note: nil
      )
      flash[:notice] = "承認を取り消しました。"
      redirect_to admin_payroll_simulation_path(@simulation)
    end

    # 一括承認
    def bulk_approve
      @year = params[:year]&.to_i || Date.current.year
      @month = params[:month]&.to_i || Date.current.month

      simulations = current_tenant.salary_simulations
        .for_period(@year, @month)
        .where(status: ['draft', 'confirmed'])

      approved_count = 0
      simulations.each do |sim|
        sim.update!(
          status: 'approved',
          approved_at: Time.current,
          approved_by_id: current_user.id
        )
        approved_count += 1
      end

      flash[:notice] = "#{approved_count}件の給与を承認しました。"
      redirect_to admin_payroll_simulations_path(year: @year, month: @month)
    end

    # Excel出力
    def export
      @year = params[:year]&.to_i || Date.current.year
      @month = params[:month]&.to_i || Date.current.month

      @simulations = current_tenant.salary_simulations
        .for_period(@year, @month)
        .includes(:employee, :salary_setting)
        .order(:employee_code)

      respond_to do |format|
        format.xlsx {
          response.headers['Content-Disposition'] = "attachment; filename=\"給与台帳_#{@year}年#{@month}月.xlsx\""
        }
      end
    end

    # 等級別基本給テーブル管理
    def grade_tables
      @grade_tables = current_tenant.grade_salary_tables.active.order(:grade_code)
    end

    def new_grade_table
      @grade_table = current_tenant.grade_salary_tables.build
      @grade_levels = current_tenant.grade_levels.active
    end

    def create_grade_table
      @grade_table = current_tenant.grade_salary_tables.build(grade_table_params)

      if @grade_table.save
        flash[:notice] = "等級「#{@grade_table.grade_code}」を登録しました。"
        redirect_to grade_tables_admin_payroll_simulations_path
      else
        @grade_levels = current_tenant.grade_levels.active
        render :new_grade_table
      end
    end

    def edit_grade_table
      @grade_table = current_tenant.grade_salary_tables.find(params[:id])
      @grade_levels = current_tenant.grade_levels.active
    end

    def update_grade_table
      @grade_table = current_tenant.grade_salary_tables.find(params[:id])

      if @grade_table.update(grade_table_params)
        flash[:notice] = "等級「#{@grade_table.grade_code}」を更新しました。"
        redirect_to grade_tables_admin_payroll_simulations_path
      else
        @grade_levels = current_tenant.grade_levels.active
        render :edit_grade_table
      end
    end

    # 従業員給与設定管理
    def salary_settings
      @salary_settings = current_tenant.salary_settings
        .includes(:employee, :grade_salary_table)
        .active
        .order('employees.employee_code')
    end

    def new_salary_setting
      @salary_setting = current_tenant.salary_settings.build
      @salary_setting.effective_from = Date.current.beginning_of_month
      @employees = current_tenant.employees.order(:employee_code)
      @grade_tables = current_tenant.grade_salary_tables.active.order(:grade_code)
    end

    def create_salary_setting
      @salary_setting = current_tenant.salary_settings.build(salary_setting_params)

      if @salary_setting.save
        flash[:notice] = "給与設定を登録しました。"
        redirect_to salary_settings_admin_payroll_simulations_path
      else
        @employees = current_tenant.employees.order(:employee_code)
        @grade_tables = current_tenant.grade_salary_tables.active.order(:grade_code)
        render :new_salary_setting
      end
    end

    def edit_salary_setting
      @salary_setting = current_tenant.salary_settings.find(params[:id])
      @employees = current_tenant.employees.order(:employee_code)
      @grade_tables = current_tenant.grade_salary_tables.active.order(:grade_code)
    end

    def update_salary_setting
      @salary_setting = current_tenant.salary_settings.find(params[:id])

      if @salary_setting.update(salary_setting_params)
        # 給与設定を更新したら、関連するシミュレーションを自動再計算
        recalculate_employee_simulations(@salary_setting.employee)

        flash[:notice] = "給与設定を更新し、シミュレーションを再計算しました。"

        # シミュレーション詳細画面から来た場合はそこに戻る
        if params[:return_to_simulation].present?
          simulation = current_tenant.salary_simulations.find_by(id: params[:return_to_simulation])
          if simulation
            redirect_to admin_payroll_simulation_path(simulation) and return
          end
        end

        redirect_to salary_settings_admin_payroll_simulations_path
      else
        @employees = current_tenant.employees.order(:employee_code)
        @grade_tables = current_tenant.grade_salary_tables.active.order(:grade_code)
        render :edit_salary_setting
      end
    end

    # 給与設定がない従業員を確認
    def missing_settings
      @year = params[:year]&.to_i || Date.current.year
      @month = params[:month]&.to_i || Date.current.month
      target_date = Date.new(@year, @month, 1)

      # 勤怠データがある従業員コード
      attendance_codes = current_tenant.attendance_monthlies
        .where(year: @year, month: @month)
        .pluck(:employee_code)

      # 給与設定がある従業員ID
      setting_employee_ids = current_tenant.salary_settings
        .active
        .effective_on(target_date)
        .pluck(:employee_id)

      # 従業員マスタにいるが給与設定がない人
      @missing_employees = current_tenant.employees
        .where(employee_code: attendance_codes)
        .where.not(id: setting_employee_ids)
        .order(:employee_code)

      # 給与データも取得
      @salary_data = {}
      @missing_employees.each do |emp|
        salary = current_tenant.salary_monthlies.find_by(
          employee_code: emp.employee_code,
          year: @year,
          month: @month,
          payment_type: 'regular'
        )
        @salary_data[emp.id] = salary if salary
      end
    end

    # 給与設定を自動生成
    def auto_create_settings
      @year = params[:year]&.to_i || Date.current.year
      @month = params[:month]&.to_i || Date.current.month
      target_date = Date.new(@year, @month, 1)
      employee_ids = params[:employee_ids] || []

      created = 0
      errors = []

      employee_ids.each do |emp_id|
        employee = current_tenant.employees.find_by(id: emp_id)
        next unless employee

        # 既存の給与設定があればスキップ
        existing = current_tenant.salary_settings
          .for_employee(employee.id)
          .effective_on(target_date)
          .active
          .first
        if existing
          errors << "#{employee.employee_code}: 既に給与設定があります"
          next
        end

        # 給与データから設定を推測
        salary = current_tenant.salary_monthlies.find_by(
          employee_code: employee.employee_code,
          year: @year,
          month: @month,
          payment_type: 'regular'
        )

        unless salary
          errors << "#{employee.employee_code}: 給与データがありません"
          next
        end

        # 給与タイプを判定
        salary_type = salary.basic_salary.to_i > 0 ? 'monthly' : 'daily'

        # 実績データから全ての固定項目をコピー
        setting = current_tenant.salary_settings.build(
          employee_id: employee.id,
          salary_type: salary_type,
          effective_from: target_date,
          active: true,
          # 基本給関連
          base_salary_override: salary.basic_salary.to_i > 0 ? salary.basic_salary : nil,
          # 基準内賃金（時給計算ベース）
          housing_allowance: salary.city_allowance,       # 大都市加算
          position_allowance: salary.position_allowance,  # 職位加算
          role_allowance: salary.role_allowance,          # 職責加算
          adjustment_salary: salary.adjustment_salary,    # 調整給
          basic_salary_2: salary.basic_salary_2,          # 基本給2
          executive_salary: salary.executive_salary,      # 役員報酬
          # 基準外手当
          adjustment_allowance: salary.adjustment_allowance,  # 調整加算
          safety_bonus: salary.safety_bonus,                  # 無事故加算
          absence_deduction: salary.absence_deduction,        # 欠勤控除
          family_allowance: salary.family_allowance,          # 家族手当
          # 通勤手当
          commuting_allowance: salary.commuting_allowance,
          # 控除
          resident_tax: salary.resident_tax,
          union_fee: salary.union_fee,
          dependents_count: salary.dependents_count,
          tax_table_type: salary.tax_table || '甲'
        )

        if setting.save
          created += 1
        else
          errors << "#{employee.employee_code}: #{setting.errors.full_messages.join(', ')}"
        end
      end

      if errors.any?
        flash[:warning] = "#{created}件作成（#{errors.size}件エラー）: #{errors.first(3).join(', ')}"
      else
        flash[:notice] = "#{created}件の給与設定を作成しました。"
      end

      redirect_to missing_settings_admin_payroll_simulations_path(year: @year, month: @month)
    end

    # 取締役の従業員コード（給与計算から除外）
    EXECUTIVE_CODES = %w[1019 1024 1111 1200].freeze

    # 給与明細一覧（実績データ）
    def salary_list
      @year = params[:year]&.to_i || Date.current.year
      @month = params[:month]&.to_i || Date.current.month

      @salaries = current_tenant.salary_monthlies
        .where(year: @year, month: @month, payment_type: 'regular')
        .where.not(employee_code: EXECUTIVE_CODES)
        .order(:employee_code)

      # 等級情報を取得
      @grades = {}
      @salaries.each do |salary|
        emp = current_tenant.employees.find_by(employee_code: salary.employee_code)
        next unless emp
        setting = SalarySetting.find_by(employee_id: emp.id)
        @grades[salary.employee_code] = setting&.grade_salary_table
      end

      # 利用可能な年月リスト
      @available_periods = current_tenant.salary_monthlies
        .where(payment_type: 'regular')
        .select(:year, :month)
        .distinct
        .order(year: :desc, month: :desc)
        .map { |s| [s.year, s.month] }
    end

    # 既存の給与設定を実績データで一括更新
    def bulk_sync_settings
      @year = params[:year]&.to_i || Date.current.year
      @month = params[:month]&.to_i || Date.current.month
      target_date = Date.new(@year, @month, 1)

      updated = 0
      errors = []

      # シミュレーションがある全従業員の給与設定を更新
      current_tenant.salary_simulations.for_period(@year, @month).each do |sim|
        next unless sim.employee

        # 実績データを取得
        salary = current_tenant.salary_monthlies.find_by(
          employee_code: sim.employee_code,
          year: @year,
          month: @month,
          payment_type: 'regular'
        )
        next unless salary

        # 勤怠データを取得（時給逆算用）
        attendance = current_tenant.attendance_monthlies.find_by(
          employee_code: sim.employee_code,
          year: @year,
          month: @month
        )

        # 給与設定を取得
        setting = current_tenant.salary_settings
          .for_employee(sim.employee_id)
          .effective_on(target_date)
          .active
          .order(effective_from: :desc)
          .first
        next unless setting

        # 実績データで更新
        setting.assign_attributes(
          housing_allowance: salary.city_allowance,
          position_allowance: salary.position_allowance,
          role_allowance: salary.role_allowance,
          adjustment_salary: salary.adjustment_salary,
          adjustment_allowance: salary.adjustment_allowance,
          basic_salary_2: salary.basic_salary_2,
          executive_salary: salary.executive_salary,
          safety_bonus: salary.safety_bonus,
          absence_deduction: salary.absence_deduction,
          family_allowance: salary.family_allowance,
          resident_tax: salary.resident_tax,
          union_fee: salary.union_fee
        )

        # 基本給が異なる場合は base_salary_override を設定
        actual_basic = salary.basic_salary.to_i
        if actual_basic > 0 && actual_basic != setting.base_salary
          setting.base_salary_override = actual_basic
        end

        # 時給を実績の残業代から逆算して設定（残業時間がある場合）
        if attendance && attendance.overtime_hours.to_f > 0 && salary.weekday_overtime_pay.to_i > 0
          implied_overtime_rate = salary.weekday_overtime_pay.to_f / attendance.overtime_hours.to_f
          implied_hourly_rate = (implied_overtime_rate / setting.overtime_rate).round
          # 現在の計算時給と10円以上異なる場合は上書き
          if (implied_hourly_rate - setting.hourly_rate).abs >= 10
            setting.hourly_rate_override = implied_hourly_rate
          end
        end

        # 適用開始日が対象月より後の場合は修正
        if setting.effective_from > target_date
          setting.effective_from = target_date
        end

        if setting.changed?
          if setting.save
            updated += 1
            # シミュレーションを再計算
            recalculate_employee_simulations(sim.employee)
          else
            errors << "#{sim.employee_code}: #{setting.errors.full_messages.join(', ')}"
          end
        end
      end

      if updated > 0 || errors.any?
        if errors.any?
          flash[:warning] = "#{updated}件更新（#{errors.size}件エラー）"
        else
          flash[:notice] = "#{updated}件の給与設定を実績データで更新し、再計算しました。"
        end
      else
        flash[:info] = "更新が必要な給与設定はありませんでした。"
      end

      redirect_to admin_payroll_simulations_path(year: @year, month: @month)
    end

    private

    def grade_table_params
      params.require(:grade_salary_table).permit(
        :grade_level_id, :grade_code, :grade_name, :base_salary, :city_allowance,
        :hourly_rate, :overtime_rate, :late_night_rate, :holiday_rate,
        :effective_from, :effective_until, :active, :notes
      )
    end

    def salary_setting_params
      params.require(:salary_setting).permit(
        :employee_id, :salary_type, :grade_salary_table_id, :base_salary_override,
        :hourly_rate_override, :commuting_allowance, :commuting_distance, :fuel_efficiency,
        :commuting_type, :commuting_daily_rate, :family_allowance, :housing_allowance,
        :position_allowance, :qualification_allowance, :safety_bonus, :safety_bonus_cumulative,
        :resident_tax, :dependents_count, :tax_table_type, :effective_from, :effective_until,
        :active, :notes,
        # 追加項目（給与明細の全項目）
        :adjustment_salary, :adjustment_allowance, :basic_salary_2, :executive_salary,
        :role_allowance, :absence_deduction, :union_fee
      )
    end

    def simulation_params
      params.require(:salary_simulation).permit(
        :calc_basic_salary, :calc_overtime_pay, :calc_late_night_pay, :calc_holiday_pay,
        :calc_paid_leave_pay, :calc_commuting_allowance, :calc_other_allowances,
        :calc_safety_bonus, :calc_health_insurance, :calc_nursing_insurance,
        :calc_pension, :calc_employment_insurance, :calc_income_tax, :calc_union_fee, :calc_resident_tax
      )
    end

    def recalculate_totals(simulation)
      # 支給合計
      simulation.calc_gross_total = simulation.calc_basic_salary.to_i +
                                    simulation.calc_overtime_pay.to_i +
                                    simulation.calc_late_night_pay.to_i +
                                    simulation.calc_holiday_pay.to_i +
                                    simulation.calc_paid_leave_pay.to_i +
                                    simulation.calc_commuting_allowance.to_i +
                                    simulation.calc_other_allowances.to_i +
                                    simulation.calc_safety_bonus.to_i

      # 控除合計
      simulation.calc_deduction_total = simulation.calc_health_insurance.to_i +
                                        simulation.calc_nursing_insurance.to_i +
                                        simulation.calc_pension.to_i +
                                        simulation.calc_employment_insurance.to_i +
                                        simulation.calc_income_tax.to_i +
                                        simulation.calc_union_fee.to_i +
                                        simulation.calc_resident_tax.to_i

      # 差引支給額
      simulation.calc_net_total = simulation.calc_gross_total - simulation.calc_deduction_total

      # 実績との差異を再計算
      actual = current_tenant.salary_monthlies.find_by(
        employee_code: simulation.employee_code,
        year: simulation.year,
        month: simulation.month,
        payment_type: 'regular'
      )

      if actual
        simulation.diff_gross = simulation.calc_gross_total - actual.gross_total.to_i
        simulation.diff_net = simulation.calc_net_total - actual.net_total.to_i
      end
    end

    # 特定従業員のシミュレーションを再計算
    def recalculate_employee_simulations(employee)
      return unless employee

      # この従業員のシミュレーションを全て再計算
      current_tenant.salary_simulations.where(employee_id: employee.id).find_each do |sim|
        calculator = SalaryCalculator.new(current_tenant, year: sim.year, month: sim.month)
        attendance = current_tenant.attendance_monthlies.find_by(
          employee_code: sim.employee_code,
          year: sim.year,
          month: sim.month
        )
        calculator.calculate_for_employee(attendance) if attendance
      end
    end
  end
end
