# frozen_string_literal: true

module Admin
  class SalaryScenariosController < BaseController
    before_action :set_scenario, only: [:show, :edit, :update, :destroy, :calculate]

    def index
      @scenarios = SalaryScenario.ordered
    end

    def show
      @results = @scenario.salary_scenario_results.ordered.includes(:employee)

      # サマリー計算
      @summary = {
        total_employees: @results.count,
        total_gross_diff: @results.sum { |r| r.diff_gross },
        increased_count: @results.count(&:increased?),
        decreased_count: @results.count(&:decreased?)
      }
    end

    def new
      @scenario = SalaryScenario.new
      @scenario.set_default_parameters!
      @periods = Period.ordered.limit(12)
    end

    def create
      @scenario = SalaryScenario.new(scenario_params)
      @scenario.parameters = build_parameters

      if @scenario.save
        redirect_to admin_salary_scenario_path(@scenario), notice: "シナリオを作成しました。試算を実行してください。"
      else
        @periods = Period.ordered.limit(12)
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      @periods = Period.ordered.limit(12)
    end

    def update
      @scenario.parameters = build_parameters

      if @scenario.update(scenario_params)
        redirect_to admin_salary_scenario_path(@scenario), notice: "シナリオを更新しました。"
      else
        @periods = Period.ordered.limit(12)
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @scenario.destroy
      redirect_to admin_salary_scenarios_path, notice: "シナリオを削除しました。"
    end

    # 試算実行
    def calculate
      period = Period.find_by(id: params[:period_id]) || Period.ordered.first

      calculator = SalaryScenarioCalculator.new(@scenario, period: period)
      results = calculator.calculate_all

      if results[:errors].any?
        flash[:alert] = "一部エラーがありました: #{results[:errors].first(3).join(', ')}"
      end

      redirect_to admin_salary_scenario_path(@scenario),
                  notice: "#{results[:calculated]}名の試算が完了しました。"
    end

    # 詳細モーダル用
    def result_detail
      @result = SalaryScenarioResult.find(params[:id])
      render partial: "result_detail", locals: { result: @result }
    end

    # ドライバー向け簡素化比較
    def driver_comparison
      @period = resolve_period || Period.ordered.first
      @periods = Period.ordered.limit(12)

      # 調整可能パラメータ（デフォルト値）
      @params = build_comparison_params

      return unless @period

      # ドライバー拠点（本社以外）
      driver_locations = %w[東京 川崎 仙台 小名浜 九州]

      # 非ドライバー（管理職・事務等）を除外
      exclude_codes = %w[1013 1119]

      # 対象従業員を取得
      emp_ids = PayrollCell.where(period: @period, location: driver_locations)
                           .distinct.pluck(:employee_id)
      @employees = Employee.where(id: emp_ids)
                           .where.not(employee_code: exclude_codes)
                           .order(:employee_code)

      # 各従業員の現行vs新給与を計算
      @comparisons = calculate_driver_comparisons(@employees, @period, @params)

      # サマリー
      @summary = {
        total: @comparisons.size,
        increased: @comparisons.count { |c| c[:diff] > 0 },
        decreased: @comparisons.count { |c| c[:diff] < 0 },
        unchanged: @comparisons.count { |c| c[:diff] == 0 },
        total_diff: @comparisons.sum { |c| c[:diff] },
        # 会社負担関連
        current_company_cost_total: @comparisons.sum { |c| c[:current_company_cost] },
        proposed_company_cost_total: @comparisons.sum { |c| c[:proposed_company_cost] },
        company_cost_diff: @comparisons.sum { |c| c[:company_cost_diff] }
      }
    end

    def driver_comparison_calculate
      # パラメータを引き継いでリダイレクト
      redirect_to driver_comparison_admin_salary_scenarios_path(
        period_id: params[:period_id],
        base_salary_1: params[:base_salary_1],
        base_salary_2: params[:base_salary_2],
        base_salary_3: params[:base_salary_3],
        base_salary_4: params[:base_salary_4],
        base_salary_5: params[:base_salary_5],
        safety_half_year: params[:safety_half_year],
        safety_one_year: params[:safety_one_year],
        difficulty_high: params[:difficulty_high],
        difficulty_mid: params[:difficulty_mid],
        difficulty_low: params[:difficulty_low],
        area_tokyo: params[:area_tokyo],
        area_sendai: params[:area_sendai]
      )
    end

    # 個人詳細比較（フルページ）
    def driver_comparison_detail
      @period = resolve_period || Period.ordered.first
      @periods = Period.ordered.limit(12)
      @params = build_comparison_params

      # 個人選択パラメータを追加
      @params[:selected_grade] = params[:selected_grade]
      @params[:selected_safety] = params[:selected_safety]
      @params[:selected_difficulty] = params[:selected_difficulty]

      # 勤怠時間パラメータを追加（指定があれば使用）
      @params[:overtime_hours] = params[:overtime_hours].to_f if params[:overtime_hours].present?
      @params[:late_night_hours] = params[:late_night_hours].to_f if params[:late_night_hours].present?
      @params[:holiday_hours] = params[:holiday_hours].to_f if params[:holiday_hours].present?

      # 職位・職責パラメータを追加（指定があれば使用）
      @params[:position_allowance] = params[:position_allowance].to_i if params[:position_allowance].present?
      @params[:role_allowance] = params[:role_allowance].to_i if params[:role_allowance].present?

      @employee = Employee.find(params[:employee_id])

      # ドライバー一覧を取得（選択用）
      driver_locations = %w[東京 川崎 仙台 小名浜 九州]
      exclude_codes = %w[1013 1119]
      emp_ids = PayrollCell.where(period: @period, location: driver_locations)
                           .distinct.pluck(:employee_id)
      @employees = Employee.where(id: emp_ids)
                           .where.not(employee_code: exclude_codes)
                           .order(:employee_code)

      # 詳細比較を実行
      service = DriverSalaryComparisonService.new(
        employee: @employee,
        period: @period,
        params: @params
      )
      @comparison = service.compare

      if @comparison.nil?
        redirect_to driver_comparison_admin_salary_scenarios_path,
                    alert: "給与設定が見つかりません"
        return
      end
    end

    # 個人詳細比較の再計算
    def driver_comparison_detail_calculate
      redirect_to driver_comparison_detail_admin_salary_scenarios_path(
        employee_id: params[:employee_id],
        period_id: params[:period_id],
        selected_grade: params[:selected_grade],
        selected_safety: params[:selected_safety],
        selected_difficulty: params[:selected_difficulty],
        overtime_hours: params[:overtime_hours],
        late_night_hours: params[:late_night_hours],
        holiday_hours: params[:holiday_hours],
        position_allowance: params[:position_allowance],
        role_allowance: params[:role_allowance],
        base_salary_1: params[:base_salary_1],
        base_salary_2: params[:base_salary_2],
        base_salary_3: params[:base_salary_3],
        base_salary_4: params[:base_salary_4],
        base_salary_5: params[:base_salary_5],
        safety_half_year: params[:safety_half_year],
        safety_one_year: params[:safety_one_year],
        difficulty_high: params[:difficulty_high],
        difficulty_mid: params[:difficulty_mid],
        difficulty_low: params[:difficulty_low],
        area_tokyo: params[:area_tokyo],
        area_sendai: params[:area_sendai]
      )
    end

    # 仮決め保存
    def save_draft
      period = Period.find(params[:period_id])
      employee = Employee.find(params[:employee_id])

      draft = SalaryDraftDecision.find_or_initialize_by(
        employee: employee,
        period: period
      )

      draft.assign_attributes(
        selected_grade: params[:selected_grade],
        selected_safety: params[:selected_safety],
        selected_difficulty: params[:selected_difficulty],
        position_allowance: params[:position_allowance].to_i,
        role_allowance: params[:role_allowance].to_i,
        overtime_hours: params[:overtime_hours].to_f,
        late_night_hours: params[:late_night_hours].to_f,
        holiday_hours: params[:holiday_hours].to_f,
        location: params[:location],
        # 現行
        current_fixed_total: params[:current_fixed_total].to_i,
        current_gross_total: params[:current_gross_total].to_i,
        current_net_total: params[:current_net_total].to_i,
        current_company_cost: params[:current_company_cost].to_i,
        # 新給与
        proposed_fixed_total: params[:proposed_fixed_total].to_i,
        proposed_gross_total: params[:proposed_gross_total].to_i,
        proposed_net_total: params[:proposed_net_total].to_i,
        proposed_company_cost: params[:proposed_company_cost].to_i,
        # 差額
        diff_fixed: params[:proposed_fixed_total].to_i - params[:current_fixed_total].to_i,
        diff_gross: params[:proposed_gross_total].to_i - params[:current_gross_total].to_i,
        diff_net: params[:proposed_net_total].to_i - params[:current_net_total].to_i,
        diff_company_cost: params[:proposed_company_cost].to_i - params[:current_company_cost].to_i
      )

      if draft.save
        redirect_to driver_comparison_detail_admin_salary_scenarios_path(
          employee_id: employee.id,
          period_id: period.id,
          selected_grade: params[:selected_grade],
          selected_safety: params[:selected_safety],
          selected_difficulty: params[:selected_difficulty],
          overtime_hours: params[:overtime_hours],
          late_night_hours: params[:late_night_hours],
          holiday_hours: params[:holiday_hours],
          position_allowance: params[:position_allowance],
          role_allowance: params[:role_allowance]
        ), notice: "仮決めを保存しました"
      else
        redirect_back fallback_location: driver_comparison_admin_salary_scenarios_path,
                      alert: "保存に失敗しました: #{draft.errors.full_messages.join(', ')}"
      end
    end

    # 仮決め削除
    def delete_draft
      draft = SalaryDraftDecision.find(params[:id])
      period = draft.period
      draft.destroy
      redirect_to draft_overview_admin_salary_scenarios_path(period_id: period.id),
                  notice: "仮決めを削除しました"
    end

    # 仮決め一覧（俯瞰）
    def draft_overview
      @period = resolve_period || Period.ordered.first
      @periods = Period.ordered.limit(12)
      @params = build_comparison_params

      # 全ドライバーを取得
      driver_locations = %w[東京 川崎 仙台 小名浜 九州]
      exclude_codes = %w[1013 1119]
      emp_ids = PayrollCell.where(period: @period, location: driver_locations)
                           .distinct.pluck(:employee_id)
      @all_employees = Employee.where(id: emp_ids)
                               .where.not(employee_code: exclude_codes)
                               .order(:employee_code)

      # 仮決め済みデータ
      @drafts = SalaryDraftDecision.for_period(@period).ordered.includes(:employee)
      @draft_by_employee = @drafts.index_by(&:employee_id)

      # 全員の比較データを計算（仮決め済みはそのデータ、未決定は自動計算）
      @comparisons = build_all_comparisons(@all_employees, @period, @params, @draft_by_employee)

      # サマリー（仮決め済みのみ）
      drafted_comparisons = @comparisons.select { |c| c[:drafted] }
      @summary = {
        total_employees: @all_employees.count,
        drafted_count: @drafts.count,
        not_drafted_count: @all_employees.count - @drafts.count,
        increased: drafted_comparisons.count { |c| c[:diff_net] > 0 },
        decreased: drafted_comparisons.count { |c| c[:diff_net] < 0 },
        unchanged: drafted_comparisons.count { |c| c[:diff_net] == 0 },
        total_net_diff: drafted_comparisons.sum { |c| c[:diff_net] },
        total_company_cost_diff: drafted_comparisons.sum { |c| c[:diff_company_cost] },
        current_company_cost_total: drafted_comparisons.sum { |c| c[:current_company_cost] },
        proposed_company_cost_total: drafted_comparisons.sum { |c| c[:proposed_company_cost] }
      }
    end

    private

    def set_scenario
      @scenario = SalaryScenario.find(params[:id])
    end

    def scenario_params
      params.require(:salary_scenario).permit(:name, :description, :is_baseline)
    end

    def build_parameters
      {
        "monthly_hours" => params.dig(:parameters, :monthly_hours).presence || 163.8,
        "overtime_rate" => params.dig(:parameters, :overtime_rate).presence || 1.25,
        "overtime_rate_over_60" => params.dig(:parameters, :overtime_rate_over_60).presence || 1.50,
        "late_night_rate" => params.dig(:parameters, :late_night_rate).presence || 0.25,
        "holiday_rate" => params.dig(:parameters, :holiday_rate).presence || 1.35,
        "base_salary_method" => params.dig(:parameters, :base_salary_method).presence || "grade_table",
        "base_salary_adjustment" => params.dig(:parameters, :base_salary_adjustment).presence || 0
      }
    end

    def resolve_period
      if params[:period_id].present?
        Period.find_by(id: params[:period_id])
      else
        Period.ordered.first
      end
    end

    # 比較用パラメータを構築（調整可能）
    def build_comparison_params
      {
        # 基本給5段階（1万円刻み）
        base_salary_1: (params[:base_salary_1] || 180_000).to_i,
        base_salary_2: (params[:base_salary_2] || 190_000).to_i,
        base_salary_3: (params[:base_salary_3] || 200_000).to_i,
        base_salary_4: (params[:base_salary_4] || 210_000).to_i,
        base_salary_5: (params[:base_salary_5] || 220_000).to_i,
        # 無事故手当
        safety_half_year: (params[:safety_half_year] || 5_000).to_i,
        safety_one_year: (params[:safety_one_year] || 10_000).to_i,
        # 難易度給（個人別に手動設定が必要）
        difficulty_high: (params[:difficulty_high] || 15_000).to_i,
        difficulty_mid: (params[:difficulty_mid] || 10_000).to_i,
        difficulty_low: (params[:difficulty_low] || 5_000).to_i,
        # エリア加算
        area_tokyo: (params[:area_tokyo] || 40_000).to_i,
        area_sendai: (params[:area_sendai] || 10_000).to_i
      }
    end

    # ドライバー比較データを計算
    # 新給与体系:
    #   基本給: 5段階（18万〜22万、1万円刻み）
    #   無事故手当: 半年5千/1年1万
    #   難易度給: 高1.5万/中1万/低5千（要手動設定）
    #   職位・職責: 現行維持
    #   エリア加算: 東京・川崎4万/仙台・小名浜1万
    #   調整給: 廃止
    def calculate_driver_comparisons(employees, period, comp_params)
      comparisons = []

      employees.each do |emp|
        setting = SalarySetting.where(employee_id: emp.id).order(effective_from: :desc).first
        next unless setting

        # 拠点を取得
        cell = PayrollCell.where(period: period, employee: emp).first
        location = cell&.location || "不明"

        # 現行給与計算
        current = calculate_current_fixed_salary(setting, period, emp)

        # 新給与計算
        proposed = calculate_proposed_fixed_salary(setting, location, comp_params)

        diff = proposed[:total] - current[:total]

        # 会社負担コスト（固定給ベースで概算）
        current_employer = calculate_employer_cost_simple(current[:total])
        proposed_employer = calculate_employer_cost_simple(proposed[:total])

        current_company_cost = current[:total] + current_employer
        proposed_company_cost = proposed[:total] + proposed_employer
        company_cost_diff = proposed_company_cost - current_company_cost

        comparisons << {
          employee: emp,
          location: location,
          current: current,
          proposed: proposed,
          diff: diff,
          current_employer: current_employer,
          proposed_employer: proposed_employer,
          current_company_cost: current_company_cost,
          proposed_company_cost: proposed_company_cost,
          company_cost_diff: company_cost_diff
        }
      end

      comparisons
    end

    # 現行の固定給計算
    def calculate_current_fixed_salary(setting, period, emp)
      # 調整給（PayrollCellから取得）
      adj_item = Item.find_by(name: "調整給", payroll_group: "base")
      adj_cell = PayrollCell.find_by(period: period, employee: emp, item: adj_item)
      adj = adj_cell&.amount.to_i

      {
        base_salary: setting.base_salary.to_i,
        safety_bonus: setting.safety_bonus.to_i,
        position: setting.position_allowance.to_i,
        role: setting.role_allowance.to_i,
        city: setting.housing_allowance.to_i,
        adjustment: adj,
        adjustment_allowance: setting.adjustment_allowance.to_i,
        total: setting.base_salary.to_i +
               setting.safety_bonus.to_i +
               setting.position_allowance.to_i +
               setting.role_allowance.to_i +
               setting.housing_allowance.to_i +
               adj +
               setting.adjustment_allowance.to_i
      }
    end

    # 新給与体系の固定給計算
    def calculate_proposed_fixed_salary(setting, location, comp_params)
      # 基本給5段階（現行の基本給に応じて割り当て）
      current_base = setting.base_salary.to_i
      new_base = case current_base
                 when 0..184_999 then comp_params[:base_salary_1]
                 when 185_000..194_999 then comp_params[:base_salary_2]
                 when 195_000..204_999 then comp_params[:base_salary_3]
                 when 205_000..214_999 then comp_params[:base_salary_4]
                 else comp_params[:base_salary_5]
                 end

      # 無事故手当（現行の金額から判定）
      current_safety = setting.safety_bonus.to_i
      new_safety = if current_safety == 0
                     0  # 無事故実績なし
                   elsif current_safety >= 5000
                     comp_params[:safety_one_year]  # 1年以上相当
                   else
                     comp_params[:safety_half_year]  # 半年相当
                   end

      # 職位・職責はそのまま
      position = setting.position_allowance.to_i
      role = setting.role_allowance.to_i

      # エリア加算（拠点別）
      new_area = case location
                 when "東京", "川崎" then comp_params[:area_tokyo]
                 when "仙台", "小名浜" then comp_params[:area_sendai]
                 else 0
                 end

      # 難易度給は個人別に手動設定が必要なため、現時点では0
      # TODO: 従業員マスタに難易度区分を追加後、自動計算可能に
      difficulty = 0

      # 調整給・調整加算は廃止
      {
        base_salary: new_base,
        safety_bonus: new_safety,
        position: position,
        role: role,
        area: new_area,
        difficulty: difficulty,
        adjustment: 0,
        adjustment_allowance: 0,
        total: new_base + new_safety + position + role + new_area + difficulty
      }
    end

    # 会社負担コスト（固定給ベースで簡易計算）
    # 健康保険・厚生年金・雇用保険・労災保険の会社負担分
    def calculate_employer_cost_simple(fixed_salary)
      # 標準報酬月額を概算で決定
      health_grade = StandardMonthlyRemuneration.health_grade_for(fixed_salary)
      pension_grade = StandardMonthlyRemuneration.pension_grade_for(fixed_salary)

      health_standard = health_grade[1]
      pension_standard = pension_grade[1]

      # 会社負担率（千分率）
      health = (health_standard * 51.0 / 1000).round      # 健康保険（福島県）
      nursing = (health_standard * 9.0 / 1000).round       # 介護保険
      pension = (pension_standard * 91.5 / 1000).round     # 厚生年金
      employment = (fixed_salary * 9.5 / 1000).round       # 雇用保険（事業主）
      workers_comp = (fixed_salary * 4.5 / 1000).round     # 労災保険（運輸業）

      health + nursing + pension + employment + workers_comp
    end

    # 全員の比較データを構築（仮決め済み/未決定含む）
    def build_all_comparisons(employees, period, comp_params, draft_by_employee)
      comparisons = []

      employees.each do |emp|
        draft = draft_by_employee[emp.id]
        cell = PayrollCell.where(period: period, employee: emp).first
        location = cell&.location || "不明"

        if draft
          # 仮決め済み：保存されたデータを使用
          comparisons << {
            employee: emp,
            location: location,
            drafted: true,
            draft: draft,
            selected_grade: draft.selected_grade,
            selected_safety: draft.selected_safety,
            selected_difficulty: draft.selected_difficulty,
            current_fixed: draft.current_fixed_total,
            current_gross: draft.current_gross_total,
            current_company_cost: draft.current_company_cost,
            proposed_fixed: draft.proposed_fixed_total,
            proposed_gross: draft.proposed_gross_total,
            proposed_company_cost: draft.proposed_company_cost,
            diff_fixed: draft.diff_fixed,
            diff_gross: draft.diff_gross,
            diff_net: draft.diff_net,
            diff_company_cost: draft.diff_company_cost
          }
        else
          # 未決定：自動計算
          setting = SalarySetting.where(employee_id: emp.id).order(effective_from: :desc).first
          next unless setting

          current = calculate_current_fixed_salary(setting, period, emp)
          proposed = calculate_proposed_fixed_salary(setting, location, comp_params)

          current_employer = calculate_employer_cost_simple(current[:total])
          proposed_employer = calculate_employer_cost_simple(proposed[:total])

          comparisons << {
            employee: emp,
            location: location,
            drafted: false,
            draft: nil,
            selected_grade: nil,
            selected_safety: nil,
            selected_difficulty: nil,
            current_fixed: current[:total],
            current_gross: current[:total],  # 固定給のみ
            current_company_cost: current[:total] + current_employer,
            proposed_fixed: proposed[:total],
            proposed_gross: proposed[:total],  # 固定給のみ
            proposed_company_cost: proposed[:total] + proposed_employer,
            diff_fixed: proposed[:total] - current[:total],
            diff_gross: proposed[:total] - current[:total],
            diff_net: proposed[:total] - current[:total],
            diff_company_cost: (proposed[:total] + proposed_employer) - (current[:total] + current_employer)
          }
        end
      end

      comparisons
    end
  end
end
