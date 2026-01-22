require "set"
require "csv"

class VehicleFinancialsController < ApplicationController
  VISIBLE_COLUMNS = 14
  DEPARTMENT_LABEL = "部門名".freeze
  YEARLY_KEY_LABELS = [
    "輸送収入",
    "車両費計",
    "修繕費計",
    "燃料費計",
    "保険料計",
    "高速代計",
    "人件費計",
    "諸経費計",
    "輸送原価計",
    "営業所損益",
    "本社人件費",
    "本社管理費",
    "損益"
  ].freeze

  def index
    @available_months = VehicleFinancialMetric.distinct.order(month: :desc).pluck(:month)
    @month_options = @available_months.map { |m| [m.strftime("%Y年%m月"), m.strftime("%Y-%m")] }
    @period_groups = build_period_groups(@available_months)
    @selected_month = parse_month(params[:month])
    @start_month = parse_month(params[:start_month])
    @end_month = parse_month(params[:end_month])
    if @start_month.present? && @end_month.present? && @start_month > @end_month
      @start_month, @end_month = @end_month, @start_month
    end
    @selected_period = params[:period].presence
    @group_by = "vehicle"
    @available_depots = available_departments
    @available_shippers = Vehicle.where.not(shipper_name: [nil, ""]).distinct.order(:shipper_name).pluck(:shipper_name)
    @selected_depot = params[:depot].presence
    @selected_shipper = params[:shipper].presence
    @visible_count = VISIBLE_COLUMNS
    @font_scale = "55"
    @yearly_view = params[:view] == "yearly"
    @summary_setting = SummarySetting.for(ActsAsTenant.current_tenant)

    # 表示モード（monthly / term / custom）
    @view_mode = params[:view_mode].presence || "monthly"

    # 集計単位（monthly: 月別 / yearly: 年間合計）
    @aggregation = params[:aggregation].presence || "monthly"

    # 期比較モード用
    @start_term = params[:start_term].presence
    @end_term = params[:end_term].presence

    # 車両グループ一覧
    @vehicle_groups = VehicleGroup.ordered
    @selected_vehicle_group_id = params[:vehicle_group_id].presence

    # 車両コード一覧（ピック機能用）- 特殊コードを除外
    excluded_codes = %w[99999 88888 77777 9999 8888 7777 66666 66700 99991 99992]
    @available_vehicle_codes = VehicleFinancialMetric
      .where.not(vehicle_code: [nil, ""])
      .where.not(vehicle_code: excluded_codes)
      .distinct
      .order(:vehicle_code)
      .pluck(:vehicle_code)

    # ユーザーが選択した車両コード（グループ選択時はグループの車両コードを使用）
    if @selected_vehicle_group_id.present?
      group = VehicleGroup.find_by(id: @selected_vehicle_group_id)
      @selected_vehicle_codes = group&.all_related_codes || []
      @selected_vehicle_group = group
    else
      @selected_vehicle_codes = Array(params[:vehicle_codes]).reject(&:blank?)
    end

    # 共通の前処理
    if @selected_period.blank? && @selected_month.present?
      @selected_period = fiscal_term(@selected_month).to_s
    end

    period_group = find_period_group(@selected_period) || @period_groups.first
    @selected_period ||= period_group&.dig(:key)
    @period_months = period_group&.dig(:months).presence || @available_months
    @period_months = @available_months if @period_months.blank?

    # 月別表示モード用：選択した期に属する月がない場合のフォールバック
    if @period_months.blank?
      @period_months = @available_months
    end

    # モード別のデータ取得
    case @view_mode
    when "term"
      # 期比較モード: 複数期の合計値を横並びで表示
      load_term_comparison_data
    when "custom"
      # カスタム期間モード: 開始月〜終了月の範囲を月別表示
      load_custom_period_data
    else
      # 月別表示モード（デフォルト）
      load_monthly_data
    end

    if @total_groups.to_i > VISIBLE_COLUMNS
      @prev_index = @start_index - VISIBLE_COLUMNS
      @prev_index = nil if @prev_index.negative?
      @next_index = @start_index + VISIBLE_COLUMNS
      @next_index = nil if @next_index >= @total_groups
    else
      @prev_index = @next_index = nil
    end

    if @yearly_view
      # 車両グループが選択されている場合はそのコードを優先、なければdepot/shipperでフィルター
      @yearly_vehicle_codes = @selected_vehicle_codes.present? ? @selected_vehicle_codes : vehicle_codes_for_filters(@selected_depot, @selected_shipper, nil)
      yearly_table = VehicleFinancialYearlyTable.new(
        start_month: @start_month,
        end_month: @end_month,
        limit_terms: 15,
        vehicle_codes: @yearly_vehicle_codes,
        depot: @selected_depot,
        shipper: @selected_shipper,
        tenant: ActsAsTenant.current_tenant,
        only_labels: @summary_setting.canonical_labels.presence || YEARLY_KEY_LABELS
      )
      @yearly_headers = yearly_table.headers
      @yearly_rows = yearly_table.rows
    end

    @output_type = params[:output_type]

    respond_to do |format|
      format.html
      format.xlsx do
        # Excel出力時は全期間のデータを取得（ページネーションなし）
        reload_full_timeline_for_excel if @group_monthly_view

        filename = excel_filename
        response.headers["Content-Disposition"] = "attachment; filename=\"#{filename}\""
        render xlsx: "index", filename: filename
      end
      format.csv do
        if @group_monthly_view && @category_table.present?
          send_data generate_group_category_csv,
                    filename: "vehicle_group_category_#{Time.current.strftime('%Y%m%d_%H%M%S')}.csv",
                    type: "text/csv; charset=utf-8"
        elsif @yearly_view
          if params[:detail].present?
            send_data generate_yearly_detail_csv(@summary_setting),
                      filename: "vehicle_yearly_detail_#{Time.current.strftime('%Y%m%d_%H%M%S')}.csv",
                      type: "text/csv; charset=utf-8"
          else
            send_data generate_yearly_monthly_csv(@summary_setting),
                      filename: "vehicle_yearly_monthly_summary_#{Time.current.strftime('%Y%m%d_%H%M%S')}.csv",
                      type: "text/csv; charset=utf-8"
          end
        else
          head :bad_request
        end
      end
    end
  end

  def show
    @vehicle_code = params[:id]
    @vehicle_tabs = vehicle_tabs(@vehicle_code)
    @start_month = parse_month(params[:start_month])
    @end_month = parse_month(params[:end_month])
    if @start_month.present? && @end_month.present? && @start_month > @end_month
      @start_month, @end_month = @end_month, @start_month
    end
    @timeline = VehicleFinancialTimeline.new(
      vehicle_code: @vehicle_code,
      page: params[:history_page].presence || 1,
      per_page: VehicleFinancialTimeline::DEFAULT_MONTH_COLUMNS,
      start_month: @start_month,
      end_month: @end_month
    )
    @timeline_headers = @timeline.headers
    @timeline_rows = @timeline.rows
    apply_month_range_filter!
    load_metric_categories

    respond_to do |format|
      format.html
      format.csv do
        filename = csv_filename
        send_data generate_vehicle_financial_csv,
                  filename: filename,
                  type: "text/csv; charset=utf-8"
      end
    end
  end

  private

  def parse_month(value)
    return value if value.is_a?(Date)
    return if value.blank?

    Date.strptime(value, "%Y-%m")
  rescue ArgumentError
    nil
  end

  def build_window_options(total, visible)
    return [] if total.zero?

    windows = []
    index = 0
    while index < total
      range_end = [index + visible, total].min
      label = "#{index + 1}-#{range_end}"
      windows << [label, index]
      index += visible
    end
    windows
  end

  def filter_rows(rows)
    hidden_labels = ["部門コード"]
    seen_labels = Set.new

    rows.each_with_object([]) do |row, filtered|
      next if hidden_labels.include?(row[:label])

      normalized = normalize_label(row[:label])
      allow_duplicate = row[:row_type] == :vehicle_header
      if !allow_duplicate && seen_labels.include?(normalized)
        next
      end

      seen_labels << normalized unless allow_duplicate
      filtered << row
    end
  end

  # 月別表示モード: 選択した期の単月データまたは年間合計を車両別に表示
  def load_monthly_data
    # @period_months は既に期グループから設定済み
    @selected_month = @period_months&.first if @selected_month.blank?
    @selected_month ||= @available_months.first
    @selected_month = @period_months.first if @selected_month.present? && @period_months.exclude?(@selected_month)

    # 年間合計モードの場合
    if @aggregation == "yearly" && @period_months.present?
      vehicle_codes = resolve_vehicle_codes(nil)
      @matrix = VehicleFinancialMatrix.new(
        months: @period_months,  # 期の全月を渡す
        group_by: @group_by,
        metrics: params[:metrics],
        depot: @selected_depot,
        shipper: @selected_shipper,
        vehicle_codes: vehicle_codes
      )
      @available_metrics = @matrix.available_metrics
      @selected_metrics = @matrix.selected_metrics
      @headers = @matrix.headers
      setup_pagination
      @rows = filter_rows(@matrix.rows(@header_window))
    elsif @selected_month.present?
      # 月別モードの場合
      vehicle_codes = resolve_vehicle_codes(@selected_month)
      @matrix = VehicleFinancialMatrix.new(
        month: @selected_month,
        group_by: @group_by,
        metrics: params[:metrics],
        depot: @selected_depot,
        shipper: @selected_shipper,
        vehicle_codes: vehicle_codes
      )
      @available_metrics = @matrix.available_metrics
      @selected_metrics = @matrix.selected_metrics
      @headers = @matrix.headers
      setup_pagination
      @rows = filter_rows(@matrix.rows(@header_window))
    else
      reset_empty_state
    end
  end

  # 期比較モード: 複数期の合計値を横並びで表示
  def load_term_comparison_data
    vehicle_codes = resolve_vehicle_codes(nil)

    # 期の範囲を計算
    start_term_int = @start_term.to_i
    end_term_int = @end_term.to_i

    # 開始・終了が逆の場合は入れ替え
    if start_term_int > end_term_int && end_term_int > 0
      start_term_int, end_term_int = end_term_int, start_term_int
    end

    # 期の範囲に対応する月の範囲を計算
    term_start_month_int = @summary_setting.term_start_month || 9
    if start_term_int > 0
      # 期の最初の月を計算（例: 75期で9月開始なら 2024年9月）
      start_year = start_term_int + 1949
      @term_range_start = Date.new(start_year, term_start_month_int, 1)
    end
    if end_term_int > 0
      # 期の最後の月を計算（例: 76期で9月開始なら 2025年8月）
      end_year = end_term_int + 1949
      end_month = term_start_month_int == 1 ? 12 : term_start_month_int - 1
      end_year += 1 if term_start_month_int > 1
      @term_range_end = Date.new(end_year, end_month, 1)
    end

    term_table = VehicleFinancialYearlyTable.new(
      start_month: @term_range_start,
      end_month: @term_range_end,
      limit_terms: 20,
      vehicle_codes: vehicle_codes,
      depot: @selected_depot,
      shipper: @selected_shipper,
      tenant: ActsAsTenant.current_tenant,
      only_labels: @summary_setting.canonical_labels.presence || YEARLY_KEY_LABELS
    )

    @headers = term_table.headers
    @header_window = @headers
    @rows = term_table.rows
    @total_groups = @headers.size
    @start_index = 0
    @visible_count = @total_groups
    @window_options = []
  end

  # カスタム期間モード: 開始月〜終了月の範囲で月ごとに集計
  def load_custom_period_data
    # カスタム期間モードでは開始月・終了月が必須
    if @start_month.blank? && @end_month.blank?
      # 初期状態：空のデータを表示
      reset_empty_state
      return
    end

    vehicle_codes = resolve_vehicle_codes(nil)

    # グループまたは車両が選択されている場合は月別タイムライン表示
    if vehicle_codes.present?
      load_group_timeline_data(vehicle_codes)
    else
      # 選択なしの場合は期ごとの合計表示（従来の動作）
      load_custom_yearly_data(vehicle_codes)
    end
  end

  # グループ/車両選択時：月別タイムライン + カテゴリ別表示
  def load_group_timeline_data(vehicle_codes)
    # 期間内の月数を計算（全期間を横スクロールで表示）
    months_count = if @start_month.present? && @end_month.present?
                     ((@end_month.year * 12 + @end_month.month) - (@start_month.year * 12 + @start_month.month) + 1)
                   else
                     100
                   end

    @group_timeline = VehicleGroupTimeline.new(
      vehicle_codes: vehicle_codes,
      page: 1,
      per_page: [months_count, 100].min,
      start_month: @start_month,
      end_month: @end_month
    )

    @timeline_headers = @group_timeline.headers
    @timeline_rows = @group_timeline.rows

    # 車両別内訳データ（JSON形式でJavaScriptに渡す）
    @breakdown_data = @group_timeline.all_breakdowns

    # カテゴリ別表示用
    load_group_metric_categories

    # 通常のグリッド表示用にも設定
    @headers = @timeline_headers.reject { |h| h[:key].to_s.start_with?("summary-", "placeholder-") }
    @header_window = @headers
    # valuesから末尾の合計・平均を除外（テンプレートで別途追加するため）
    @rows = @timeline_rows.map do |row|
      row.merge(values: row[:values][0...-2])
    end
    @total_groups = @headers.size
    @start_index = 0
    @visible_count = @total_groups
    @window_options = []

    # グループ月別表示フラグ
    @group_monthly_view = true
  end

  # 従来の期ごと合計表示
  def load_custom_yearly_data(vehicle_codes)
    custom_table = VehicleFinancialYearlyTable.new(
      start_month: @start_month,
      end_month: @end_month,
      limit_terms: 20,
      vehicle_codes: vehicle_codes,
      depot: @selected_depot,
      shipper: @selected_shipper,
      tenant: ActsAsTenant.current_tenant,
      only_labels: @summary_setting.canonical_labels.presence || YEARLY_KEY_LABELS
    )

    @headers = custom_table.headers
    @header_window = @headers
    @rows = custom_table.rows
    @total_groups = @headers.size
    @start_index = 0
    @visible_count = @total_groups
    @window_options = []
  end

  # グループ用のカテゴリ別集計
  def load_group_metric_categories
    @metric_categories = []
    return unless @timeline_headers.present? && @timeline_rows.present?

    @category_headers = @timeline_headers.reject { |header| summary_header?(header) }
    header_indexes = @timeline_headers.each_index.reject { |idx| summary_header?(@timeline_headers[idx]) }
    category_rows = @timeline_rows.map do |row|
      row.merge(values: header_indexes.map { |idx| row[:values][idx] })
    end

    @metric_categories = MetricCategory.ordered.includes(:items)
    all_ids = @metric_categories.map(&:id)
    requested_ids = Array(params[:category_ids]).map(&:to_i).presence || all_ids
    @selected_category_ids = requested_ids & all_ids
    @selected_category_ids = all_ids if @selected_category_ids.empty?
    @selected_categories = @metric_categories.select { |cat| @selected_category_ids.include?(cat.id) }
    @category_table = VehicleFinancialCategoryTable.new(
      headers: @category_headers,
      rows: category_rows,
      categories: @selected_categories
    )
    @profit_check = build_profit_check(@category_table)
  end

  # 車両コードを解決（ピック選択 or フィルター条件）
  def resolve_vehicle_codes(month)
    if @selected_vehicle_codes.present?
      @selected_vehicle_codes
    else
      vehicle_codes_for_filters(@selected_depot, @selected_shipper, month)
    end
  end

  # ページネーション設定
  def setup_pagination
    @total_groups = @headers.size
    @visible_count = [@visible_count, @total_groups].select(&:positive?).min || @total_groups
    @window_options = build_window_options(@total_groups, VISIBLE_COLUMNS)
    @start_index = params[:start].to_i
    @start_index = 0 if @start_index.negative?
    @start_index = [@total_groups - @visible_count, 0].max if @start_index >= @total_groups

    @header_window = (@headers[@start_index, VISIBLE_COLUMNS] || []).map do |header|
      header.merge(link_path: header.fetch(:link_path, nil))
    end
    placeholder_index = 0
    while @header_window.length < VISIBLE_COLUMNS
      placeholder_index += 1
      @header_window << { key: "placeholder-#{placeholder_index}", title: "", link_path: nil }
    end
  end

  # 空の状態にリセット
  def reset_empty_state
    @matrix = nil
    @available_metrics = []
    @selected_metrics = []
    @headers = []
    @header_window = []
    @rows = []
    @total_groups = 0
    @window_options = []
    @start_index = 0
  end

  def normalize_label(label)
    label.to_s
         .unicode_normalize(:nfkc)
         .tr("０-９Ａ-Ｚａ-ｚ", "0-9A-Za-z")
         .gsub(/\s+/, "")
         .downcase
  rescue StandardError
    label.to_s.gsub(/\s+/, "").downcase
  end

  def build_period_groups(months)
    months.group_by { |m| fiscal_term(m) }.map do |term, terms_months|
      sorted = terms_months.compact.sort.reverse
      {
        key: term.to_s,
        label: "#{term}期 (#{sorted.first&.year || '-'}年)",
        months: sorted
      }
    end.sort_by { |group| -group[:key].to_i }
  end

  def fiscal_term(month)
    return nil unless month
    year = month.year
    # 期の開始が9月の場合：9月〜翌年8月で1期
    if month.month >= 9
      year - 1949
    else
      (year - 1) - 1949
    end
  end

  def find_period_group(key)
    return if key.blank?

    @period_groups.find { |group| group[:key] == key.to_s }
  end

  def vehicle_tabs(current_code)
    codes = VehicleFinancialMetric
            .where.not(vehicle_code: [nil, ""])
            .select(:vehicle_code)
            .distinct
            .order(:vehicle_code)
            .pluck(:vehicle_code)
    codes << current_code if current_code.present? && !codes.include?(current_code)
    codes
  end

  def available_departments
    scope = VehicleFinancialMetric.where(metric_label: DEPARTMENT_LABEL)
    scope = scope.where(month: @selected_month) if @selected_month.present?
    scope.where.not(value_text: [nil, ""]).distinct.order(:value_text).pluck(:value_text)
  end

  def vehicle_codes_for_filters(depot, shipper, month)
    code_sets = []
    code_sets << vehicle_codes_from_department(depot, month) if depot.present?
    code_sets << vehicle_codes_from_shipper(shipper) if shipper.present?
    return if code_sets.empty?

    code_sets.reduce(nil) do |memo, codes|
      memo.nil? ? codes : (memo & codes)
    end
  end

  def vehicle_codes_from_department(depot, month)
    scope = VehicleFinancialMetric.where(metric_label: DEPARTMENT_LABEL, value_text: depot)
    scope = scope.where(month: month) if month.present?
    scope.distinct.pluck(:vehicle_code)
  end

  def vehicle_codes_from_shipper(shipper)
    return [] if shipper.blank?

    Vehicle.where(shipper_name: shipper).pluck(:call_sign, :registration_number).flatten.compact.uniq
  end

  def load_metric_categories
    @metric_categories = []
    return unless @timeline_headers.present? && @timeline_rows.present?

    @category_headers = @timeline_headers.reject { |header| summary_header?(header) }
    header_indexes = @timeline_headers.each_index.reject { |idx| summary_header?(@timeline_headers[idx]) }
    category_rows = @timeline_rows.map do |row|
      row.merge(values: header_indexes.map { |idx| row[:values][idx] })
    end

    @metric_categories = MetricCategory.ordered.includes(:items)
    all_ids = @metric_categories.map(&:id)
    requested_ids = Array(params[:category_ids]).map(&:to_i).presence || all_ids
    @selected_category_ids = requested_ids & all_ids
    @selected_category_ids = all_ids if @selected_category_ids.empty?
    @selected_categories = @metric_categories.select { |cat| @selected_category_ids.include?(cat.id) }
    @category_table = VehicleFinancialCategoryTable.new(
      headers: @category_headers,
      rows: category_rows,
      categories: @selected_categories
    )
    @profit_check = build_profit_check(@category_table)
  end

  def apply_month_range_filter!
    return unless (@start_month.present? || @end_month.present?) && @timeline_headers.present?

    month_indexes = []
    @timeline_headers.each_with_index do |header, index|
      month = parse_header_month(header[:key])
      next if month.nil?
      next if @start_month.present? && month < @start_month
      next if @end_month.present? && month > @end_month

      month_indexes << index
    end

    return if month_indexes.empty?

    summary_cols = summary_headers(@timeline_headers)
    month_headers = month_indexes.map { |idx| @timeline_headers[idx] }
    @timeline_headers = month_headers + summary_cols
    @timeline_rows = @timeline_rows.map do |row|
      month_values = month_indexes.map { |idx| row[:values][idx] }
      row.merge(values: month_values + summary_values_for(row))
    end
  end

  def apply_month_range_scope(scope)
    if @start_month.present? && @end_month.present?
      scope.where(month: @start_month..@end_month)
    elsif @start_month.present?
      scope.where("month >= ?", @start_month)
    elsif @end_month.present?
      scope.where("month <= ?", @end_month)
    else
      scope
    end
  end

  def parse_header_month(key)
    return nil if key.blank?

    Date.strptime(key, "%Y-%m")
  rescue ArgumentError
    nil
  end

  def csv_filename
    base = @vehicle_code
    suffix = category_view? ? "category" : "raw"
    "vehicle_financial_#{base}_#{suffix}_#{Time.current.strftime('%Y%m%d_%H%M%S')}.csv"
  end

  def excel_filename
    base = if @selected_vehicle_group.present?
             @selected_vehicle_group.name.gsub(/[\/\\:*?"<>|]/, "_")
           elsif @selected_vehicle_codes.present?
             "vehicles_#{@selected_vehicle_codes.size}"
           elsif @selected_month.present?
             @selected_month.strftime("%Y%m")
           else
             "all"
           end
    "vehicle_financial_#{base}_#{Time.current.strftime('%Y%m%d_%H%M%S')}.xlsx"
  end

  # Excel出力用に全期間のタイムラインデータを再取得（ページネーションなし）
  def reload_full_timeline_for_excel
    vehicle_codes = @selected_vehicle_codes
    return if vehicle_codes.blank?

    # 期間内の月数を計算してper_pageに設定（最大100ヶ月）
    months_count = if @start_month.present? && @end_month.present?
                     ((@end_month.year * 12 + @end_month.month) - (@start_month.year * 12 + @start_month.month) + 1)
                   else
                     100
                   end

    @group_timeline = VehicleGroupTimeline.new(
      vehicle_codes: vehicle_codes,
      page: 1,
      per_page: [months_count, 100].min,
      start_month: @start_month,
      end_month: @end_month
    )

    @timeline_headers = @group_timeline.headers
    @timeline_rows = @group_timeline.rows
    @breakdown_data = @group_timeline.all_breakdowns

    # カテゴリ別テーブルも再構築
    load_group_metric_categories

    @headers = @timeline_headers.reject { |h| h[:key].to_s.start_with?("summary-", "placeholder-") }
    @header_window = @headers
    # valuesから末尾の合計・平均を除外（テンプレートで別途追加するため）
    @rows = @timeline_rows.map do |row|
      row.merge(values: row[:values][0...-2])
    end
  end

  def category_view?
    params[:view] == "category"
  end

  def generate_vehicle_financial_csv
    if category_view? && @category_table.present?
      headers = ["カテゴリ", "項目名"] + @category_headers.map { |header| header[:title] } + ["合計", "平均"]
      CSV.generate do |csv|
        csv << headers
        @category_table.rows.each do |row|
          next if row.type == :section && row.category.items.blank?

          if row.type == :section
            csv << [row.label]
            next
          end

          summary = view_context.vehicle_financial_row_summary(row)
          values = row.values.map { |val| view_context.vehicle_financial_value_text(row.label, val) }
          csv << [row.category.display_label, row.label, *values,
                  view_context.vehicle_financial_value_text(row.label, summary[:total]),
                  view_context.vehicle_financial_value_text(row.label, summary[:average])]
        end
        blank_columns = Array.new(@category_table.column_count, "")
        csv << ["", "合計", *blank_columns,
                view_context.vehicle_financial_value_text("合計", @category_table.total_values_sum),
                view_context.vehicle_financial_value_text("合計", @category_table.total_average_value)]
        csv << ["", "平均", *blank_columns,
                "",
                view_context.vehicle_financial_value_text("平均", @category_table.average_summary_value)]
      end
    else
      headers = ["区分", "項目名"] + @timeline_headers.map { |header| header[:title] }
      CSV.generate do |csv|
        csv << headers
        current_section = nil
        @timeline_rows.each do |row|
          section_label = view_context.vehicle_financial_section_label(row)
          display_section = section_label.present? && section_label != current_section ? section_label : nil
          current_section = section_label if section_label.present?

          values = row[:values].map do |value|
            view_context.vehicle_financial_value_text(row[:label], value)
          end
          csv << ([display_section, row[:label]] + values)
        end
      end
    end
  end

  def summary_header_keys
    @summary_header_keys ||= VehicleFinancialTimeline::SUMMARY_HEADERS.map { |header| header[:key].to_s }
  end

  def summary_header?(header)
    summary_header_keys.include?(header[:key].to_s)
  end

  def summary_headers(headers = @timeline_headers)
    Array(headers).select { |header| summary_header?(header) }
  end

  def summary_values_for(row)
    count = summary_header_keys.length
    return [] if count.zero?

    Array(row[:values]).last(count) || []
  end

  def build_profit_check(table)
    return nil unless table

    config = profit_check_config
    net = table.net_profit_values(revenue_labels: config[:revenue_labels], cost_labels: config[:cost_labels])
    recorded = table.values_for_label(config[:profit_label])

    missing = Array(net[:missing])
    missing << config[:profit_label] if recorded.nil?
    return { missing_labels: missing.uniq } if missing.present? || net[:values].nil? || recorded.nil?

    diff = net[:values].each_with_index.map do |calc, index|
      calc.to_f - recorded[index].to_f
    end

    {
      calc_label: "検算損益（売上-費用合計）",
      profit_label: config[:profit_label],
      calc_values: net[:values],
      recorded_values: recorded,
      diff_values: diff,
      missing_labels: []
    }
  end

  def profit_check_config
    {
      revenue_labels: ["売上"],
      cost_labels: ["固定費", "変動費", "ドライバー人件費", "営業所管理費", "営業所人件費", "本社人件費", "本社管理費"],
      profit_label: "損益"
    }
  end

  def generate_yearly_monthly_csv(setting)
    labels = setting.canonical_labels.presence || YEARLY_KEY_LABELS
    alias_map = setting.label_mappings
    target_labels = labels + alias_map.values.flatten

    scope = VehicleFinancialMetric.left_joins(:vehicle)
    scope = scope.where(vehicle_financial_metrics: { tenant_id: ActsAsTenant.current_tenant.id }) if ActsAsTenant.current_tenant
    scope = scope.where(vehicle_financial_metrics: { vehicle_code: @yearly_vehicle_codes }) if defined?(@yearly_vehicle_codes) && @yearly_vehicle_codes.present?
    scope = scope.where.not(vehicle_financial_metrics: { vehicle_code: [nil, ""] })
    scope = scope.where(vehicles: { depot_name: @selected_depot }) if @selected_depot.present? && @yearly_vehicle_codes.blank?
    scope = scope.where(vehicles: { shipper_name: @selected_shipper }) if @selected_shipper.present? && @yearly_vehicle_codes.blank?
    scope = scope.where(metric_label: target_labels)

    single_month = params[:month].present? ? parse_month(params[:month]) : nil
    if single_month && @start_month.blank? && @end_month.blank?
      scope = scope.where(month: single_month)
    else
      scope = apply_month_range_scope(scope)
    end

    summary = Hash.new(0.0)
    scope.where.not(value_numeric: nil).select(:id, :metric_label, :month, :value_numeric).find_each do |record|
      term = fiscal_term_with_setting(record.month, setting.term_start_month)
      next if term.nil?

      canonical = canonical_label_with_setting(record.metric_label, setting)
      next unless labels.any? { |lbl| canonical_label_with_setting(lbl, setting) == canonical }

      month_key = record.month.strftime("%Y-%m")
      summary[[term, month_key, canonical]] += record.value_numeric.to_f
    end

    headers = ["期", "月", "項目名", "合計"]
    CSV.generate do |csv|
      csv << headers
      summary.keys.sort_by { |term, month, label| [-term.to_i, month, label] }.each do |key|
        term, month_key, canonical = key
        display_label = labels.find { |lbl| canonical_label_with_setting(lbl, setting) == canonical } || canonical
        csv << [term, month_key, display_label, summary[key]]
      end
    end
  end

  # 明細をそのまま出力（検算用）
  def generate_yearly_detail_csv(setting)
    labels = setting.canonical_labels.presence || YEARLY_KEY_LABELS
    alias_map = setting.label_mappings
    target_labels = labels + alias_map.values.flatten

    scope = VehicleFinancialMetric.left_joins(:vehicle)
    scope = scope.where(vehicle_financial_metrics: { tenant_id: ActsAsTenant.current_tenant.id }) if ActsAsTenant.current_tenant
    scope = scope.where(vehicle_financial_metrics: { vehicle_code: @yearly_vehicle_codes }) if defined?(@yearly_vehicle_codes) && @yearly_vehicle_codes.present?
    scope = scope.where.not(vehicle_financial_metrics: { vehicle_code: [nil, ""] })
    scope = scope.where(vehicles: { depot_name: @selected_depot }) if @selected_depot.present? && @yearly_vehicle_codes.blank?
    scope = scope.where(vehicles: { shipper_name: @selected_shipper }) if @selected_shipper.present? && @yearly_vehicle_codes.blank?
    scope = scope.where(metric_label: target_labels)

    single_month = params[:month].present? ? parse_month(params[:month]) : nil
    if single_month && @start_month.blank? && @end_month.blank?
      scope = scope.where(month: single_month)
    else
      scope = apply_month_range_scope(scope)
    end

    headers = ["期", "月", "車両コード", "項目（元）", "項目（正規化）", "数値"]
    CSV.generate do |csv|
      csv << headers
      scope.where.not(value_numeric: nil).select(:id, :metric_label, :vehicle_code, :month, :value_numeric).find_each do |record|
        term = fiscal_term_with_setting(record.month, setting.term_start_month)
        next if term.nil?

        canonical = canonical_label_with_setting(record.metric_label, setting)
        next unless labels.any? { |lbl| canonical_label_with_setting(lbl, setting) == canonical }

        csv << [
          term,
          record.month.strftime("%Y-%m"),
          record.vehicle_code,
          record.metric_label,
          canonical,
          record.value_numeric.to_f
        ]
      end
    end
  end

  def canonical_label_with_setting(label, setting)
    normalized = normalize_label(label)
    setting.label_mappings.each do |canonical, aliases|
      return normalize_label(canonical) if Array(aliases).map { |a| normalize_label(a) }.include?(normalized) || normalize_label(canonical) == normalized
    end
    normalized
  end

  def fiscal_term_with_setting(month, start_month)
    return nil unless month
    if month.month >= start_month.to_i
      month.year - 1949
    else
      (month.year - 1) - 1949
    end
  end

  def generate_group_category_csv
    headers = ["カテゴリ", "項目名"] + @category_headers.map { |h| h[:title] } + ["合計", "平均"]

    # BOM（Byte Order Mark）を手動で追加してExcelでの文字化けを防ぐ
    bom = "\uFEFF"
    bom + CSV.generate do |csv|
      # グループ情報をヘッダーに
      if @selected_vehicle_group.present?
        csv << ["グループ名", @selected_vehicle_group.name]
        csv << ["車両数", @selected_vehicle_group.vehicle_codes&.size || 0]
        csv << ["期間", "#{@start_month&.strftime('%Y年%m月')} 〜 #{@end_month&.strftime('%Y年%m月')}"]
        csv << []
      end

      csv << headers

      current_category_id = nil
      @category_table.rows.each do |row|
        next if row.type == :section

        display_category = nil
        if row.category&.id != current_category_id
          current_category_id = row.category&.id
          display_category = row.category&.display_label
        end

        summary = view_context.vehicle_financial_row_summary(row)
        values = row.values.map { |val| format_csv_value(row.label, val) }
        csv << [
          display_category,
          row.label,
          *values,
          format_csv_value(row.label, summary[:total]),
          format_csv_value(row.label, summary[:average])
        ]
      end

      # 検算行
      if @profit_check && @profit_check[:missing_labels].blank?
        csv << []
        csv << ["", @profit_check[:calc_label], *@profit_check[:calc_values].map { |v| format_csv_value("損益", v) }, format_csv_value("損益", @profit_check[:calc_values]&.compact&.sum), ""]
        csv << ["", @profit_check[:profit_label], *@profit_check[:recorded_values].map { |v| format_csv_value("損益", v) }, format_csv_value("損益", @profit_check[:recorded_values]&.compact&.sum), ""]
        csv << ["", "差額(検算-損益)", *@profit_check[:diff_values].map { |v| format_csv_value("損益", v) }, format_csv_value("損益", @profit_check[:diff_values]&.compact&.sum), ""]
      end

      # 合計・平均行
      csv << []
      blank_columns = Array.new(@category_table.column_count, "")
      csv << ["", "合計", *blank_columns, format_csv_value("合計", @category_table.total_values_sum), format_csv_value("合計", @category_table.total_average_value)]
      csv << ["", "平均", *blank_columns, "", format_csv_value("平均", @category_table.average_summary_value)]
    end
  end

  def format_csv_value(label, value)
    return "" if value.nil?
    return value.to_s if value.is_a?(String)

    value.is_a?(Numeric) ? value.round(0).to_i : value
  end

end
