require "set"
require "csv"

class VehicleFinancialsController < ApplicationController
  VISIBLE_COLUMNS = 14
  DEPARTMENT_LABEL = "部門名".freeze

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

    if @selected_period.blank? && @selected_month.present?
      @selected_period = fiscal_term(@selected_month).to_s
    end

    period_group = find_period_group(@selected_period) || @period_groups.first
    @selected_period ||= period_group&.dig(:key)
    @period_months = period_group ? period_group[:months] : @available_months
    @period_months = @available_months if @period_months.blank?
    @period_months = @period_months.select { |m| @start_month.blank? || m >= @start_month }
    @period_months = @period_months.select { |m| @end_month.blank? || m <= @end_month }
    if @selected_month.blank?
      @selected_month = @period_months&.first
    end
    @selected_month ||= @available_months.first

    if @selected_month.present? && @period_months.exclude?(@selected_month)
      @selected_month = @period_months.first
    end

    if @selected_month.present?
      vehicle_codes = vehicle_codes_for_filters(@selected_depot, @selected_shipper, @selected_month)
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
      @total_groups = @headers.size
      @visible_count = [@visible_count, @total_groups].select(&:positive?).min || @total_groups
      @window_options = build_window_options(@total_groups, VISIBLE_COLUMNS)
      @start_index = params[:start].to_i
      @start_index = 0 if @start_index.negative?
      if @start_index >= @total_groups
        @start_index = [@total_groups - @visible_count, 0].max
      end
      @header_window = (@headers[@start_index, VISIBLE_COLUMNS] || []).map do |header|
        header.merge(
          link_path: header.fetch(:link_path, nil)
        )
      end
      placeholder_index = 0
      while @header_window.length < VISIBLE_COLUMNS
        placeholder_index += 1
        @header_window << { key: "placeholder-#{placeholder_index}", title: "", link_path: nil }
      end
      @rows = filter_rows(@matrix.rows(@header_window))
    else
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

    if @total_groups.to_i > VISIBLE_COLUMNS
      @prev_index = @start_index - VISIBLE_COLUMNS
      @prev_index = nil if @prev_index.negative?
      @next_index = @start_index + VISIBLE_COLUMNS
      @next_index = nil if @next_index >= @total_groups
    else
      @prev_index = @next_index = nil
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
    month.year - 1949
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

end
