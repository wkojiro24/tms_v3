# 複数車両の収支データを合算して月別タイムラインを生成
class VehicleGroupTimeline
  SUMMARY_HEADERS = [
    { key: "summary-total", title: "合計" },
    { key: "summary-average", title: "平均" }
  ].freeze

  DEFAULT_MONTH_COLUMNS = 12

  attr_reader :vehicle_codes, :page, :per_page, :start_month, :end_month

  def initialize(vehicle_codes:, tenant: ActsAsTenant.current_tenant || Tenant.first, page: 1, per_page: DEFAULT_MONTH_COLUMNS, start_month: nil, end_month: nil)
    @vehicle_codes = Array(vehicle_codes).reject(&:blank?)
    @tenant = tenant
    @page = [page.to_i, 1].max
    @per_page = per_page
    @start_month = start_month
    @end_month = end_month
    if @start_month.present? && @end_month.present? && @start_month > @end_month
      @start_month, @end_month = @end_month, @start_month
    end
    load_data
  end

  def headers
    base_headers = @months.map do |month|
      {
        key: month.strftime("%Y-%m"),
        title: month.strftime("%Y.%m")
      }
    end

    placeholder_index = 0
    while base_headers.length < @per_page
      placeholder_index += 1
      base_headers << { key: "placeholder-month-#{placeholder_index}", title: "" }
    end

    base_headers + SUMMARY_HEADERS
  end

  def rows
    @rows
  end

  # 車両別の内訳データを取得
  # @param label [String] メトリクスラベル
  # @param month_key [String] 月キー (例: "2025-03")
  # @return [Array<Hash>] 車両別内訳 [{code: "1234", value: 12345}, ...]
  def breakdown_for(label, month_key)
    @breakdown_data&.dig(label, month_key) || []
  end

  # 全ての内訳データを取得（JSON APIやフロントエンド用）
  def all_breakdowns
    @breakdown_data || {}
  end

  def total_pages
    return 0 if @per_page.zero?

    (@total_months.to_f / @per_page).ceil
  end

  def current_page
    @page
  end

  def vehicle_count
    @vehicle_codes.size
  end

  private

  attr_reader :tenant

  def scope
    @scope ||= begin
      base = VehicleFinancialMetric.where(tenant_id: tenant.id)
      if @vehicle_codes.present?
        base.where(vehicle_code: @vehicle_codes)
      else
        base.where.not(vehicle_code: [nil, ""])
      end
    end
  end

  def load_data
    months_scope = scope.select(:month).distinct.order(month: :desc)
    months_scope = apply_month_range(months_scope)
    @total_months = months_scope.count
    @months = months_scope.offset((page - 1) * per_page).limit(per_page).pluck(:month)
    @months.reverse!
    records = scope.where(month: @months).order(:month)
    @available_metrics = determine_metrics(records)
    month_index = @months.each_with_index.to_h

    # 複数車両のデータを合算
    map = Hash.new { |hash, key| hash[key] = Array.new(@per_page) { 0.0 } }
    metadata_map = {}

    # 車両別内訳データを保存（label -> month_key -> [{code:, value:}]）
    @breakdown_data = Hash.new { |h, k| h[k] = Hash.new { |h2, k2| h2[k2] = [] } }

    records.each do |record|
      index = month_index[record.month]
      next if index.nil?

      label = record.metric_label.to_s
      metadata_map[label] ||= record.metadata || {}
      month_key = record.month.strftime("%Y-%m")

      # 車両別内訳を保存（nilも含めて記録）
      @breakdown_data[label][month_key] << {
        code: record.vehicle_code,
        value: record.value_numeric&.to_f
      }

      next if record.value_numeric.nil?

      # 数値を合算
      map[label][index] += record.value_numeric.to_f
    end

    @rows = @available_metrics.map do |label|
      meta = metadata_map[label] || {}
      month_values = map[label]&.dup || Array.new(@per_page) { 0.0 }
      if month_values.length < @per_page
        month_values += Array.new(@per_page - month_values.length) { 0.0 }
      end
      # 0.0を維持（値がない場合は0として表示）
      values = append_summary(month_values)
      {
        label: label,
        section_label: meta["section_label"],
        row_type: classify_row(label, meta),
        values: values
      }
    end
  end

  def determine_metrics(records)
    rows = records.pluck(:metric_label, Arel.sql("(vehicle_financial_metrics.metadata->>'row_index')::int"))
    order_map = {}
    rows.each do |label, row_index|
      order_map[label] ||= row_index || Float::INFINITY
    end
    sorted = order_map.sort_by { |label, idx| [idx || Float::INFINITY, label.to_s] }.map(&:first)
    final_idx = sorted.find_index { |label| normalize_label(label) == VehicleFinancialMatrix::FINAL_LABEL }
    if final_idx
      sorted.take(final_idx + 1)
    else
      stop_idx = sorted.find_index { |label| stop_label?(label) }
      stop_idx ? sorted.take(stop_idx) : sorted
    end
  end

  def stop_label?(label)
    stripped = normalize_label(label)
    VehicleFinancialMatrix::STOP_LABEL_PATTERNS.any? { |pattern| stripped.match?(pattern) }
  end

  def normalize_label(label)
    label.to_s.delete("　").strip
  end

  def append_summary(values)
    numeric_values = values.compact.select { |value| value.is_a?(Numeric) && value != 0 }
    total = numeric_values.sum if numeric_values.any?
    average = if numeric_values.any? && numeric_values.length.positive?
                total / numeric_values.length
              end
    values + [total, average]
  end

  def classify_row(label, metadata)
    normalized = normalize_label(label)
    return :vehicle_header if VehicleFinancialMatrix::VEHICLE_HEADER_LABELS.include?(normalized)
    return :grand_total if VehicleFinancialMatrix::GRAND_TOTAL_LABELS.include?(normalized)
    return :subtotal if normalized.match?(VehicleFinancialMatrix::SUBTOTAL_PATTERN)

    section_label = metadata["section_label"].to_s
    if section_label.present? && section_label == label && VehicleFinancialMatrix::SECTION_HEADERS.include?(normalized)
      return :section_header
    end

    :detail
  end

  def apply_month_range(months_scope)
    if start_month.present? && end_month.present?
      months_scope.where(month: start_month..end_month)
    elsif start_month.present?
      months_scope.where("month >= ?", start_month)
    elsif end_month.present?
      months_scope.where("month <= ?", end_month)
    else
      months_scope
    end
  end
end
