module Admin
  class PayrollsController < BaseController
    before_action :authorize_admin!

    def index
      @periods = Period.ordered.limit(24)
      if @periods.blank?
        flash.now[:alert] = "対象期間がまだ登録されていません。"
        @visible_count_options = [13]
        @window_options = []
        @employees = []
        @items = []
        @cell_map = {}
        @total_employees = 0
        @visible_count = 13
        @start_index = 0
        @locations = []
        return
      end

      @period = resolve_period || @periods.first

      @locations = PayrollBatch.where(period: @period).distinct.pluck(:location)
      @locations = PayrollCell.where(period: @period).distinct.pluck(:location) if @locations.empty?
      @locations = @locations.compact.presence || ["default"]

      @location = params[:location].presence || @locations.first

      @column_orders = PayrollColumnOrder.where(period: @period, location: @location).includes(:employee)
      @all_employees = resolve_employees(@column_orders)
      @total_employees = @all_employees.size

      # 常に全員表示（横スクロールで見る）
      @visible_count = @total_employees
      @start_index = 0
      @employees = @all_employees
      @visible_count_options = [@total_employees]
      @window_options = []

      @item_orders = ItemOrder.where(period: @period, location: @location).includes(:item)
      @items = resolve_items(@item_orders)

      @cells = PayrollCell.where(period: @period, location: @location).includes(:item, :employee)
      @cell_map = @cells.each_with_object({}) do |cell, hash|
        hash[[cell.item_id, cell.employee_id]] = cell
      end

      # 従業員別の時給を計算（基準内賃金 ÷ 167）
      @hourly_rates = calculate_hourly_rates(@employees, @cell_map)

      # 基準内賃金の内訳（表示用）
      @base_salary_details = calculate_base_salary_details(@employees, @cell_map)

      # 変動給と算出根拠のマッピング（同名項目）
      @variable_basis_map = build_variable_basis_map

      # グループ別に項目を整理
      @grouped_items = build_grouped_items(@items)
    end

    def build_grouped_items(items)
      # 非表示項目を除外
      visible_items = items.reject(&:hidden?)
      grouped = visible_items.group_by(&:payroll_group)

      # 給与明細の流れに沿った順序
      group_order = %w[
        base allowance variable_basis variable taxable_subtotal
        commute gross_total welfare tax_insurance deduction_total
        net_pay reference other
      ]

      result = []
      group_order.each do |group|
        group_items = grouped[group] || []
        next if group_items.empty?

        result << {
          group: group,
          label: Item::PAYROLL_GROUPS[group],
          items: group_items.sort_by { |i| [i.payroll_group_position || 999, i.name] },
          show_subtotal: group == "base"
        }
      end

      # 未設定の項目
      ungrouped = grouped[nil] || []
      if ungrouped.any?
        result << {
          group: nil,
          label: "未設定",
          items: ungrouped.sort_by(&:name),
          show_subtotal: false
        }
      end

      result
    end

    def destroy
      period = Period.find(params[:period_id])
      location = params[:location].presence

      PayrollCell.where(period:, location: location).delete_all
      ItemOrder.where(period:, location: location).delete_all
      PayrollColumnOrder.where(period:, location: location).delete_all
      PayrollBatch.where(period:, location: location).delete_all

      redirect_to admin_payrolls_path(period_id: period.id),
                  notice: "#{period.label} #{location || 'default'} の給与データを削除しました。"
    end

    private

    def authorize_admin!
      authorize! :access, :admin
    end

    def resolve_period
      if params[:period_id].present?
        Period.find_by(id: params[:period_id])
      elsif params[:target_month].present? && params[:target_month].match?(/\A\d{4}-\d{2}\z/)
        year, month = params[:target_month].split("-").map(&:to_i)
        Period.find_by(year:, month:)
      else
        Period.order(year: :desc, month: :desc).first
      end
    end

    def resolve_employees(column_orders)
      if column_orders.any?
        column_orders.map(&:employee)
      else
        PayrollCell.where(period: @period, location: @location)
                   .includes(:employee)
                   .map(&:employee)
                   .uniq
                   .sort_by(&:employee_code)
      end
    end

    def resolve_items(item_orders)
      if item_orders.any?
        item_orders.map(&:item)
      else
        PayrollCell.where(period: @period, location: @location)
                   .includes(:item)
                   .map(&:item)
                   .uniq
                   .sort_by(&:name)
      end
    end

    def build_window_options(total, window)
      return [[display_range_label(1, total), 0]] if total.zero? || window.zero? || total <= window

      options = []
      start = 0
      while start < total
        finish = [start + window, total].min
        options << [display_range_label(start + 1, finish), start]
        start += window
      end
      options
    end

    def build_visible_count_options(total)
      return [13] if total.zero?
      return [total].uniq if total <= 13

      base = [13, 26, 39, 52, total].uniq.sort
      base.select { |count| count.positive? && count <= total }
    end

    def display_range_label(start, finish)
      finish = start if finish < start
      "#{start} - #{finish}"
    end

    # 従業員別の時給を計算（基準内賃金 ÷ 167時間）
    # 賃金規則第21条第3項: 年間所定総労働時間(2008h)の月間平均(167h)で除す
    MONTHLY_HOURS = 167.0

    # 基準内賃金に含める基本項目（賃金規則第2章に基づく）
    # 第14条 基本給、第16条 無事故継続加算、第18条 職位加算、
    # 第19条 職責・役割加算、第20条 大都市勤務加算
    BASE_SALARY_CORE_ITEMS = %w[基本給 無事故加算 職位加算 職責加算 大都市加算].freeze
    # 調整項目（調整給があれば調整給を、なければ調整加算を使用）第15条
    BASE_SALARY_ADJ_ITEMS = %w[調整給 調整加算].freeze

    def calculate_hourly_rates(employees, cell_map)
      # 基準内賃金に含める項目を取得
      core_items = Item.where(name: BASE_SALARY_CORE_ITEMS, payroll_group: "base")
      adj_salary_item = Item.find_by(name: "調整給", payroll_group: "base")
      adj_add_item = Item.find_by(name: "調整加算", payroll_group: "base")
      return {} if core_items.empty?

      rates = {}
      employees.each do |employee|
        # コア項目の合計
        base_total = core_items.sum do |item|
          cell = cell_map[[item.id, employee.id]]
          cell ? helpers.payroll_numeric_value(cell).to_i : 0
        end

        # 調整項目（調整給があればそれを、なければ調整加算を加算）
        adj_salary = 0
        if adj_salary_item
          cell = cell_map[[adj_salary_item.id, employee.id]]
          adj_salary = cell ? helpers.payroll_numeric_value(cell).to_i : 0
        end

        if adj_salary > 0 && adj_salary < 30000  # 小額の調整給のみ含める（大額はみなし残業手当の可能性）
          base_total += adj_salary
        elsif adj_add_item
          cell = cell_map[[adj_add_item.id, employee.id]]
          adj_add = cell ? helpers.payroll_numeric_value(cell).to_i : 0
          base_total += adj_add
        end

        # 時給計算（50銭未満切捨て、50銭以上切り上げ）
        rates[employee.id] = base_total > 0 ? (base_total / MONTHLY_HOURS).round : 0
      end

      rates
    end

    # 基準内賃金の内訳を取得（表示用）
    def calculate_base_salary_details(employees, cell_map)
      core_items = Item.where(name: BASE_SALARY_CORE_ITEMS, payroll_group: "base")
      adj_salary_item = Item.find_by(name: "調整給", payroll_group: "base")
      adj_add_item = Item.find_by(name: "調整加算", payroll_group: "base")
      return {} if core_items.empty?

      details = {}
      employees.each do |employee|
        emp_details = {}

        # コア項目
        core_items.each do |item|
          cell = cell_map[[item.id, employee.id]]
          value = cell ? helpers.payroll_numeric_value(cell).to_i : 0
          emp_details[item.name] = value if value > 0
        end

        # 調整項目
        adj_salary = 0
        if adj_salary_item
          cell = cell_map[[adj_salary_item.id, employee.id]]
          adj_salary = cell ? helpers.payroll_numeric_value(cell).to_i : 0
        end

        if adj_salary > 0 && adj_salary < 30000
          emp_details["調整給"] = adj_salary
        elsif adj_add_item
          cell = cell_map[[adj_add_item.id, employee.id]]
          adj_add = cell ? helpers.payroll_numeric_value(cell).to_i : 0
          emp_details["調整加算"] = adj_add if adj_add > 0
        end

        details[employee.id] = emp_details
      end

      details
    end

    # 変動給と算出根拠のマッピング
    def build_variable_basis_map
      basis_items = Item.where(payroll_group: "variable_basis")
      variable_items = Item.where(payroll_group: "variable")

      # 名前の対応表
      name_mapping = {
        "法定休日残業" => "法定休日時間",
        "法定外休日残" => "法定外休時間",
        "法定代休残業" => "法定代休時間",
        "法定外代休残" => "法定外代時間"
      }

      basis_by_name = basis_items.index_by(&:name)

      mapping = {}
      variable_items.each do |var_item|
        # まず同名を探す
        basis_name = name_mapping[var_item.name] || var_item.name
        basis_item = basis_by_name[basis_name]
        mapping[var_item.id] = basis_item.id if basis_item
      end

      mapping
    end

    # 変動給の標準倍率（就業規則に基づく）
    def self.overtime_rates
      {
        "割増残業" => 1.25,      # 法定外残業（60h以下）
        "平日残業" => 1.25,      # 法定外残業
        "深夜残業" => 0.25,      # 深夜加算分のみ
        "法定休日残業" => 1.35,  # 休日勤務
        "法定外休日残" => 1.35,  # 休日勤務
        "法定代休残業" => 1.25,
        "法定外代休残" => 1.25
      }
    end
  end
end
