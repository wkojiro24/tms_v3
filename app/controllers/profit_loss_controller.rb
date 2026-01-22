class ProfitLossController < ApplicationController
  before_action :authenticate_user!
  before_action :set_period, except: [:drilldown, :dashboard]
  helper_method :fiscal_period_number_for

  def index
    @view_mode = params[:view_mode] || "monthly"

    @pl_data = ProfitLossService.new(
      tenant: current_tenant,
      period_start: @period_start,
      period_end: @period_end
    ).generate

    @comparison_data = if params[:compare].present?
      comparison_start, comparison_end = parse_comparison_period
      ProfitLossService.new(
        tenant: current_tenant,
        period_start: comparison_start,
        period_end: comparison_end
      ).generate
    end

    @monthly_data = ProfitLossService.new(
      tenant: current_tenant,
      period_start: @fiscal_year_start,
      period_end: @fiscal_year_end
    ).generate_monthly

    @ytd_data = ProfitLossService.new(
      tenant: current_tenant,
      period_start: @fiscal_year_start,
      period_end: @period_end
    ).generate
  end

  def dashboard
    @fiscal_year = params[:fiscal_year]&.to_i || fiscal_year_for(Date.current)
    start_month = summary_setting.term_start_month
    @fiscal_year_start = Date.new(@fiscal_year, start_month, 1)
    @fiscal_year_end = @fiscal_year_start.next_year - 1.day

    # 当期の月次データ
    @current_monthly = ProfitLossService.new(
      tenant: current_tenant,
      period_start: @fiscal_year_start,
      period_end: [@fiscal_year_end, Date.current].min
    ).generate_monthly

    # 前期の月次データ
    prev_year_start = @fiscal_year_start - 1.year
    prev_year_end = @fiscal_year_end - 1.year
    @prev_monthly = ProfitLossService.new(
      tenant: current_tenant,
      period_start: prev_year_start,
      period_end: prev_year_end
    ).generate_monthly

    # 年度累計
    @ytd_data = ProfitLossService.new(
      tenant: current_tenant,
      period_start: @fiscal_year_start,
      period_end: [@fiscal_year_end, Date.current].min
    ).generate

    # 前年同期累計
    @prev_ytd_data = ProfitLossService.new(
      tenant: current_tenant,
      period_start: prev_year_start,
      period_end: [prev_year_end, Date.current - 1.year].min
    ).generate

    @fiscal_year_label = "第#{fiscal_period_number_for(@fiscal_year)}期（#{@fiscal_year}年度）"
  end

  def drilldown
    @account_name = params[:account]
    @period_start = Date.parse(params[:start])
    @period_end = Date.parse(params[:end])

    @journal_lines = JournalLine.joins(:journal_entry)
                                .where(journal_entries: { entry_date: @period_start..@period_end })
                                .where("journal_lines.account_name LIKE ?", "%#{@account_name}%")
                                .includes(journal_entry: :journal_lines)
                                .order("journal_entries.entry_date DESC")
                                .limit(100)

    # 補助科目がない場合、相手勘定（買掛金等）の補助科目から取引先名を取得
    @vendor_names = {}
    @journal_lines.each do |line|
      next if line.sub_account_name.present?

      # 同じ伝票の貸方（相手勘定）から補助科目を取得
      counter_line = line.journal_entry.journal_lines.find do |l|
        l.id != line.id && l.sub_account_name.present?
      end

      if counter_line&.sub_account_name.present?
        @vendor_names[line.id] = counter_line.sub_account_name
      end
    end

    @totals = {
      debit: @journal_lines.where(side: "debit").sum(:amount),
      credit: @journal_lines.where(side: "credit").sum(:amount)
    }

    render partial: "drilldown", layout: false
  end

  def department_analysis
    @view_mode = params[:view_mode] || "yearly"
    @fiscal_year = params[:fiscal_year]&.to_i || fiscal_year_for(Date.current)
    start_month = summary_setting.term_start_month
    @fiscal_year_start = Date.new(@fiscal_year, start_month, 1)
    @fiscal_year_end = @fiscal_year_start.next_year - 1.day

    # 月次モードの場合は選択月の期間を設定
    if @view_mode == "monthly"
      @selected_year = params[:year]&.to_i || Date.current.year
      @selected_month = params[:month]&.to_i || Date.current.month
      @period_start = Date.new(@selected_year, @selected_month, 1)
      @period_end = @period_start.end_of_month
      @prev_period_start = @period_start - 1.month
      @prev_period_end = @prev_period_start.end_of_month
      @period_label = "#{@selected_year}年#{@selected_month}月"
    else
      @period_start = @fiscal_year_start
      @period_end = [@fiscal_year_end, Date.current].min
      @prev_period_start = @fiscal_year_start - 1.year
      @prev_period_end = [@fiscal_year_end - 1.year, Date.current - 1.year].min
      @period_label = "第#{fiscal_period_number_for(@fiscal_year)}期（#{@fiscal_year}年度）"
    end

    # 部門一覧を取得
    @departments = JournalLine.joins(:journal_entry)
      .where(journal_entries: { entry_date: @period_start..@period_end })
      .where.not(dept_name: [nil, ""])
      .distinct.pluck(:dept_name).sort

    # 分析対象の費目リスト
    @expense_categories = [
      { key: "fuel", name: "軽油代", pattern: "%軽油%" },
      { key: "consumables", name: "消耗品費", pattern: "%消耗%" },
      { key: "repair", name: "修繕費", pattern: "%修繕%" },
      { key: "toll", name: "高速代", pattern: "%高速%" },
      { key: "insurance", name: "保険料", pattern: "%保険%" },
      { key: "lease", name: "リース料", pattern: "%リース%" }
    ]

    @selected_expense = params[:expense] || "fuel"
    expense_config = @expense_categories.find { |e| e[:key] == @selected_expense } || @expense_categories.first

    # 部門別月次データを取得（年次モードのみ）
    if @view_mode == "yearly"
      @monthly_data = fetch_department_monthly_data(expense_config[:pattern])
    end

    # 部門別累計
    @department_totals = fetch_department_totals(expense_config[:pattern], @period_start, @period_end)

    # 異常値検出（平均からの乖離）
    @anomalies = detect_anomalies(@department_totals)

    # 前期データ
    @prev_department_totals = fetch_department_totals(expense_config[:pattern], @prev_period_start, @prev_period_end)

    # 取引先（補助科目）別データ
    @vendor_totals = fetch_vendor_totals(expense_config[:pattern], @period_start, @period_end)
    @vendor_by_department = fetch_vendor_by_department(expense_config[:pattern], @period_start, @period_end)

    @fiscal_year_label = @period_label
  end

  private

  def set_period
    @view_mode = params[:view_mode] || "monthly"

    if @view_mode == "yearly"
      start_month = summary_setting.term_start_month
      if params[:fiscal_year].present?
        year = params[:fiscal_year].to_i
        @fiscal_year_start = Date.new(year, start_month, 1)
        @fiscal_year_end = @fiscal_year_start.next_year - 1.day
      else
        @fiscal_year_start = fiscal_year_start_for(Date.current)
        @fiscal_year_end = @fiscal_year_start.next_year - 1.day
      end
      @period_start = @fiscal_year_start
      @period_end = [@fiscal_year_end, Date.current].min
    else
      if params[:year].present? && params[:month].present?
        @period_start = Date.new(params[:year].to_i, params[:month].to_i, 1)
        @period_end = @period_start.end_of_month
      else
        @period_start = Date.current.beginning_of_month
        @period_end = Date.current.end_of_month
      end
      @fiscal_year_start = fiscal_year_start_for(@period_start)
      @fiscal_year_end = @fiscal_year_start.next_year - 1.day
    end

    @fiscal_year_label = "#{@fiscal_year_start.year}年度（第#{fiscal_period_number}期）"
  end

  def fiscal_year_start_for(date)
    start_month = summary_setting.term_start_month
    if date.month >= start_month
      Date.new(date.year, start_month, 1)
    else
      Date.new(date.year - 1, start_month, 1)
    end
  end

  def fiscal_period_number
    base_year = summary_setting.fiscal_year_origin || SummarySetting::DEFAULT_FISCAL_YEAR_ORIGIN
    @fiscal_year_start.year - base_year + 1
  end

  def fiscal_period_number_for(year)
    base_year = summary_setting.fiscal_year_origin || SummarySetting::DEFAULT_FISCAL_YEAR_ORIGIN
    year - base_year + 1
  end

  def fiscal_year_for(date)
    start_month = summary_setting.term_start_month
    date.month >= start_month ? date.year : date.year - 1
  end

  def summary_setting
    @summary_setting ||= SummarySetting.for(current_tenant)
  end

  def parse_comparison_period
    case params[:compare]
    when "prev_month"
      prev = @period_start - 1.month
      [prev.beginning_of_month, prev.end_of_month]
    when "prev_year"
      [(@period_start - 1.year).beginning_of_month, (@period_end - 1.year).end_of_month]
    when "prev_fiscal_year"
      [@fiscal_year_start - 1.year, @fiscal_year_end - 1.year]
    else
      [@period_start, @period_end]
    end
  end

  def fetch_department_monthly_data(pattern)
    result = {}

    raw_data = JournalLine.joins(:journal_entry)
      .where(journal_entries: { entry_date: @fiscal_year_start..@period_end })
      .where("account_name LIKE ?", pattern)
      .where(side: "debit")
      .where.not(dept_name: [nil, ""])
      .select("dept_name, DATE_TRUNC('month', journal_entries.entry_date) as month, SUM(amount) as total")
      .group("dept_name, DATE_TRUNC('month', journal_entries.entry_date)")
      .order("month")

    raw_data.each do |row|
      month_key = row.month.strftime("%Y-%m")
      result[month_key] ||= {}
      result[month_key][row.dept_name] = row.total.to_i
    end

    result
  end

  def fetch_department_totals(pattern, period_start = nil, period_end = nil)
    period_start ||= @fiscal_year_start
    period_end ||= @period_end

    JournalLine.joins(:journal_entry)
      .where(journal_entries: { entry_date: period_start..period_end })
      .where("account_name LIKE ?", pattern)
      .where(side: "debit")
      .where.not(dept_name: [nil, ""])
      .group(:dept_name)
      .sum(:amount)
      .transform_values(&:to_i)
  end

  def detect_anomalies(department_totals)
    return [] if department_totals.empty?

    values = department_totals.values
    avg = values.sum / values.size.to_f
    std_dev = Math.sqrt(values.map { |v| (v - avg)**2 }.sum / values.size)

    anomalies = []
    department_totals.each do |dept, amount|
      deviation = std_dev > 0 ? ((amount - avg) / std_dev) : 0
      if deviation.abs > 1.5
        anomalies << {
          department: dept,
          amount: amount,
          deviation: deviation.round(2),
          status: deviation > 0 ? "high" : "low"
        }
      end
    end

    anomalies.sort_by { |a| -a[:deviation].abs }
  end

  def fetch_vendor_totals(pattern, period_start = nil, period_end = nil)
    period_start ||= @period_start
    period_end ||= @period_end

    # まず直接の補助科目を試す
    direct_vendors = JournalLine.joins(:journal_entry)
      .where(journal_entries: { entry_date: period_start..period_end })
      .where("account_name LIKE ?", pattern)
      .where(side: "debit")
      .where.not(sub_account_name: [nil, ""])
      .group(:sub_account_name)
      .sum(:amount)
      .transform_values(&:to_i)

    # 直接の補助科目がない場合、相手勘定（買掛金）の補助科目から取得
    if direct_vendors.empty?
      direct_vendors = fetch_vendor_from_counterpart(pattern, period_start, period_end)
    end

    direct_vendors.sort_by { |_, v| -v }.to_h
  end

  def fetch_vendor_by_department(pattern, period_start = nil, period_end = nil)
    period_start ||= @period_start
    period_end ||= @period_end
    result = {}

    # まず直接の補助科目を試す
    raw_data = JournalLine.joins(:journal_entry)
      .where(journal_entries: { entry_date: period_start..period_end })
      .where("account_name LIKE ?", pattern)
      .where(side: "debit")
      .where.not(sub_account_name: [nil, ""])
      .where.not(dept_name: [nil, ""])
      .group(:dept_name, :sub_account_name)
      .sum(:amount)

    if raw_data.empty?
      # 相手勘定（買掛金）の補助科目から取得
      result = fetch_vendor_by_department_from_counterpart(pattern, period_start, period_end)
    else
      raw_data.each do |(dept, vendor), amount|
        result[dept] ||= {}
        result[dept][vendor] = amount.to_i
      end
    end

    result
  end

  def fetch_vendor_from_counterpart(pattern, period_start, period_end)
    # 対象費目の仕訳エントリIDを取得
    entry_ids = JournalLine.joins(:journal_entry)
      .where(journal_entries: { entry_date: period_start..period_end })
      .where("account_name LIKE ?", pattern)
      .where(side: "debit")
      .pluck(:journal_entry_id)
      .uniq

    return {} if entry_ids.empty?

    # 同じ伝票の買掛金（貸方）の補助科目を取得
    JournalLine.joins(:journal_entry)
      .where(journal_entry_id: entry_ids)
      .where(side: "credit")
      .where("account_name LIKE ?", "%買掛%")
      .where.not(sub_account_name: [nil, ""])
      .group(:sub_account_name)
      .sum(:amount)
      .transform_values(&:to_i)
      .reject { |k, _| k.include?("貯") || k.include?("小口") }  # 内部科目を除外
  end

  def fetch_vendor_by_department_from_counterpart(pattern, period_start, period_end)
    result = {}

    # 対象費目の仕訳明細を取得
    expense_lines = JournalLine.joins(:journal_entry)
      .where(journal_entries: { entry_date: period_start..period_end })
      .where("account_name LIKE ?", pattern)
      .where(side: "debit")
      .where.not(dept_name: [nil, ""])
      .select(:journal_entry_id, :dept_name, :amount)

    expense_lines.each do |expense_line|
      # 同じ伝票の買掛金の補助科目を取得
      credit_line = JournalLine.find_by(
        journal_entry_id: expense_line.journal_entry_id,
        side: "credit"
      )

      next unless credit_line&.sub_account_name.present?
      vendor = credit_line.sub_account_name

      # 内部科目を除外
      next if vendor.include?("貯") || vendor.include?("小口")

      dept = expense_line.dept_name
      result[dept] ||= {}
      result[dept][vendor] ||= 0
      result[dept][vendor] += expense_line.amount.to_i
    end

    result
  end
end
