require "set"

class VehicleFinancialsController < ApplicationController
  VISIBLE_COLUMNS = 14
  DEPARTMENT_LABEL = "部門名".freeze

  def index
    @available_months = VehicleFinancialMetric.distinct.order(month: :desc).pluck(:month)
    @period_groups = build_period_groups(@available_months)
    @selected_month = parse_month(params[:month])
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
    if @selected_month.blank?
      @selected_month = @period_months&.first
    end
    @selected_month ||= @available_months.first

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
    @timeline = VehicleFinancialTimeline.new(
      vehicle_code: @vehicle_code,
      page: params[:history_page].presence || 1
    )
    @timeline_headers = @timeline.headers
    @timeline_rows = @timeline.rows
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

end
