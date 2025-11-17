class VehicleFinancialTimeline
  SUMMARY_HEADERS = [
    { key: "summary-total", title: "合計" },
    { key: "summary-average", title: "平均" }
  ].freeze

  DEFAULT_MONTH_COLUMNS = 12

  attr_reader :vehicle_code, :page, :per_page

  def initialize(vehicle_code:, tenant: ActsAsTenant.current_tenant || Tenant.first, page: 1, per_page: DEFAULT_MONTH_COLUMNS)
    @vehicle_code = vehicle_code
    @tenant = tenant
    @page = [page.to_i, 1].max
    @per_page = per_page
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

  def total_pages
    return 0 if @per_page.zero?

    (@total_months.to_f / @per_page).ceil
  end

  def current_page
    @page
  end

  def vehicle_label
    vehicle&.registration_number.presence || vehicle&.call_sign.presence || vehicle_code
  end

  private

  attr_reader :tenant

  def vehicle
    @vehicle ||= Vehicle.find_by(call_sign: vehicle_code) ||
                 Vehicle.find_by(registration_number: vehicle_code)
  end

  def scope
    @scope ||= VehicleFinancialMetric.where(tenant_id: tenant.id, vehicle_code: vehicle_code)
  end

  def load_data
    months_scope = scope.select(:month).distinct.order(month: :desc)
    @total_months = months_scope.count
    @months = months_scope.offset((page - 1) * per_page).limit(per_page).pluck(:month)
    @months.reverse!
    records = scope.where(month: @months).order(:month)
    @available_metrics = determine_metrics(records)
    month_index = @months.each_with_index.to_h

    map = Hash.new { |hash, key| hash[key] = Array.new(@per_page) }
    metadata_map = {}

    records.each do |record|
      index = month_index[record.month]
      next if index.nil?
      next if record.value_numeric.nil? && record.value_text.blank?

      label = record.metric_label.to_s
      metadata_map[label] ||= record.metadata || {}

      if record.value_numeric.present?
        existing = map[label][index]
        numeric_total = existing.is_a?(Numeric) ? existing : 0
        map[label][index] = numeric_total + record.value_numeric.to_f
      else
        map[label][index] = record.value_text
      end
    end

    @rows = @available_metrics.map do |label|
      meta = metadata_map[label] || {}
      month_values = map[label]&.dup || Array.new(@per_page)
      if month_values.length < @per_page
        month_values += Array.new(@per_page - month_values.length)
      end
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
    numeric_values = values.compact.select { |value| value.is_a?(Numeric) }
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
end
