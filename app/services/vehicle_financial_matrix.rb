require "set"

class VehicleFinancialMatrix
  STOP_LABEL_PATTERNS = [
    /(営業所|本社).*(配賦|割振)/,
    /配賦$/
  ].freeze
  FINAL_LABEL = "損益".freeze
  SECTION_HEADERS = %w[車両費 修繕費 燃料費 保険料 高速代 人件費 諸経費].freeze
  GRAND_TOTAL_LABELS = %w[輸送原価計 営業所損益 本社人件費 本社管理費 損益].freeze
  SUBTOTAL_PATTERN = /(計|合計)\z/
  VEHICLE_HEADER_LABELS = %w[車番 部門コード 部門名 ドライバー名 年式 タイヤ本数 車種名].freeze
  HEADER_LABELS = {
    department_code: "部門コード",
    department_name: "部門名",
    driver_name: "ドライバー名",
    model_year: "年式",
    tire_count: "タイヤ本数",
    vehicle_type: "車種名",
    car_number: "車番"
  }.freeze
  DEFAULT_METRICS = [
    "輸送収入",
    "走行Km",
    "燃料費計",
    "減価償却",
    "リース",
    "リース費",
    "修繕費",
    "修繕費計"
  ].freeze

  attr_reader :month, :months, :group_by, :selected_metrics, :depot, :shipper, :vehicle_codes

  # month: 単一月（Date）または nil
  # months: 複数月の配列（年間合計用）
  def initialize(month: nil, months: nil, group_by: "vehicle", metrics: nil, depot: nil, shipper: nil, vehicle_codes: nil)
    @month = month
    @months = Array(months).compact if months.present?
    @group_by = group_by.presence || "vehicle"
    @depot = depot.presence
    @shipper = shipper.presence
    @vehicle_codes = Array(vehicle_codes).flatten.compact.uniq
    @base_scope = build_scope
    @available_metrics = fetch_available_metrics
    @selected_metrics = determine_metrics(metrics)
    @header_attributes = build_header_attributes
    @row_metadata = {}
    @data = build_data
  end

  def headers
    @headers ||= group_details.values.sort_by { |detail| detail[:title].to_s }
  end

  def rows(header_subset = nil)
    target_headers = header_subset.presence || headers
    header_keys = target_headers.map { |h| h[:key] }
    seen = Set.new
    selected_metrics.each_with_object([]) do |metric, collection|
      metadata = row_metadata(metric)
      row_type = classify_row(metric, metadata)
      normalized = normalize_label(metric)
      next if row_type != :vehicle_header && seen.include?(normalized)

      seen << normalized unless row_type == :vehicle_header
      collection << {
        label: metric,
        section_label: metadata[:section_label],
        row_type: row_type,
        values: header_keys.map { |key| value_for(metric, key) },
        cell_states: header_keys.map { |key| cell_state_for(metric, key) }
      }
    end
  end

  def available_metrics
    @available_metrics
  end

  private

  attr_reader :base_scope

  def build_scope
    scope = VehicleFinancialMetric.left_joins(:vehicle)
    # 複数月指定の場合は months を使用、単一月の場合は month を使用
    if months.present?
      scope = scope.where(vehicle_financial_metrics: { month: months })
    elsif month.present?
      scope = scope.where(vehicle_financial_metrics: { month: month })
    end
    scope = scope.where(vehicles: { depot_name: depot }) if depot.present? && vehicle_codes.blank?
    scope = scope.where(vehicles: { shipper_name: shipper }) if shipper.present? && vehicle_codes.blank?
    scope = scope.where(vehicle_financial_metrics: { vehicle_code: vehicle_codes }) if vehicle_codes.present?
    scope
  end

  def fetch_available_metrics
    rows = base_scope.pluck(:metric_label, Arel.sql("(vehicle_financial_metrics.metadata->>'row_index')::int"))
    order_map = {}
    rows.each do |label, row_index|
      order_map[label] ||= row_index || Float::INFINITY
    end
    sorted = order_map.sort_by { |label, idx| [idx || Float::INFINITY, label.to_s] }.map(&:first)
    final_idx = sorted.find_index { |label| normalize_label(label) == FINAL_LABEL }
    if final_idx
      sorted.take(final_idx + 1)
    else
      stop_idx = sorted.find_index { |label| stop_label?(label) }
      stop_idx ? sorted.take(stop_idx) : sorted
    end
  end

  def determine_metrics(metric_param)
    selected = Array(metric_param).reject(&:blank?)
    selected = available_metrics if selected.empty?
    valid = (selected & available_metrics)
    return valid if valid.present?

    available_metrics
  end

  def build_data
    details = group_details
    map = {}
    @cell_state_map = {}
    metric_labels = selected_metrics

    scoped = base_scope.where(vehicle_financial_metrics: { metric_label: metric_labels })

    scoped.find_each do |record|
      key = group_key(record)
      next if key.blank?

      details[key] ||= build_group_detail(record, key)
      label = record.metric_label.to_s
      store_row_metadata(label, record.metadata)

      # cell_state を保存（error > blank > value の優先度）
      current_state = @cell_state_map[[label, key]]
      new_state = record.cell_state
      @cell_state_map[[label, key]] = prioritize_cell_state(current_state, new_state)

      # blank や error でも value が nil の場合はスキップ
      next if record.value_numeric.nil? && record.value_text.blank?

      if record.value_numeric.present?
        existing = map[[label, key]]
        numeric_total = existing.is_a?(Numeric) ? existing : 0
        map[[label, key]] = numeric_total + record.value_numeric.to_f
      elsif record.value_text.present?
        map[[label, key]] = record.value_text
      end
    end

    map
  end

  def value_for(metric, key)
    @data.fetch([metric, key], nil)
  end

  def cell_state_for(metric, key)
    @cell_state_map&.fetch([metric, key], nil)
  end

  def value_with_state_for(metric, key)
    {
      value: value_for(metric, key),
      cell_state: cell_state_for(metric, key)
    }
  end

  def stop_label?(label)
    stripped = normalize_label(label)
    STOP_LABEL_PATTERNS.any? { |pattern| stripped.match?(pattern) }
  end

  def normalize_label(label)
    label.to_s.delete("　").strip
  end

  def header_attributes
    @header_attributes ||= {}
  end

  def row_metadata(label)
    @row_metadata[label] || {}
  end

  def store_row_metadata(label, metadata)
    return if @row_metadata.key?(label)

    meta_hash = metadata || {}
    @row_metadata[label] = {
      section_label: meta_hash["section_label"],
      row_index: meta_hash["row_index"]
    }
  end

  def classify_row(label, metadata)
    normalized = normalize_label(label)
    return :vehicle_header if VEHICLE_HEADER_LABELS.include?(normalized)
    return :grand_total if GRAND_TOTAL_LABELS.include?(normalized)
    return :subtotal if normalized.match?(SUBTOTAL_PATTERN)

    section_label = metadata[:section_label].to_s
    if section_label.present? && section_label == label && SECTION_HEADERS.include?(normalized)
      return :section_header
    end

    :detail
  end

  def group_key(record)
    case group_by
    when "shipper"
      record.vehicle&.shipper_name.presence || "未設定"
    when "depot"
      department_label_for(record) || record.vehicle&.depot_name.presence || "未設定"
    else
      record.vehicle_code.presence || record.vehicle&.registration_number.presence || "不明"
    end
  end

  def build_group_detail(record, key)
    case group_by
    when "shipper"
      {
        key: key,
        title: key,
        subtitle: record.vehicle&.depot_name
      }
    when "depot"
      {
        key: key,
        title: key,
        subtitle: "営業所"
      }
    else
      header = header_attributes[key] || {}
      {
        key: key,
        title: header[HEADER_LABELS[:car_number]].presence || key,
        subtitle: nil,
        link_path: vehicle_financial_detail_path(key)
      }
    end
  end

  def group_details
    @group_details ||= {}
  end

  def build_header_attributes
    labels = HEADER_LABELS.values
    attrs = Hash.new { |hash, vehicle_code| hash[vehicle_code] = {} }
    scope = base_scope.where(vehicle_financial_metrics: { metric_label: labels })
    scope.find_each do |record|
      key = record.vehicle_code.to_s
      next if key.blank?

      value = record.value_text.presence || record.value_numeric
      next if value.blank?

      attrs[key][record.metric_label.to_s] = value
    end
    attrs
  end

  def vehicle_financial_detail_path(vehicle_code)
    Rails.application.routes.url_helpers.vehicle_financial_path(vehicle_code)
  rescue StandardError
    nil
  end

  def department_label_for(record)
    key = record.vehicle_code.to_s
    header_attributes[key][HEADER_LABELS[:department_name]]
  end

  def header_subtitle(header)
    parts = [
      header[HEADER_LABELS[:driver_name]],
      header[HEADER_LABELS[:model_year]],
      header[HEADER_LABELS[:vehicle_type]]
    ].compact
    return if parts.empty?

    parts.join(" / ")
  end

  # cell_state の優先度: error > blank > value
  def prioritize_cell_state(current, new_state)
    return new_state if current.nil?

    priority = { "error" => 3, "blank" => 2, "value" => 1 }
    current_priority = priority[current.to_s] || 0
    new_priority = priority[new_state.to_s] || 0

    new_priority > current_priority ? new_state : current
  end
end
