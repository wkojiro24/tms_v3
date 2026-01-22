require "set"

class VehicleFinancialYearlyTable
  attr_reader :headers, :rows

  ALIAS_MAP = {
    "輸送収入計" => "輸送収入",
    "輸送収入合計" => "輸送収入"
  }.freeze

  # システム用のラベル（表示から除外）
  SYSTEM_LABELS = %w[_ignored_suspicious_pairs].freeze

  def initialize(start_month:, end_month:, limit_terms: 15, vehicle_codes: nil, depot: nil, shipper: nil, tenant: ActsAsTenant.current_tenant, only_labels: nil)
    @start_month = start_month
    @end_month = end_month
    @limit_terms = limit_terms
    @vehicle_codes = Array(vehicle_codes).presence
    @depot = depot.presence
    @shipper = shipper.presence
    @tenant_id = tenant&.id
    @setting = SummarySetting.for(tenant)
    @term_start_month = @setting.term_start_month || SummarySetting::DEFAULT_TERM_START_MONTH
    @only_labels = Array(only_labels).presence || @setting.canonical_labels
    @label_aliases = @setting.label_mappings
    load_data
  end

  private

  def load_data
    scope = base_scope
    scope = apply_month_range(scope)

    target_labels = Array(@only_labels.presence || SummarySetting::DEFAULT_LABELS)
    alias_keys = @label_aliases.values.flatten - target_labels
    all_targets = (target_labels + alias_keys).uniq

    # 車両コードがあるレコードを全て集計する（vehicle_idがnullでもOK）
    # 集計用特殊コード（99999, 88888, 77777等）は除外
    records = scope.where(metric_label: all_targets)
                   .where.not(vehicle_code: excluded_vehicle_codes)
    months = records.pluck(:month).compact
    terms = months.map { |m| fiscal_term(m) }.uniq.sort.reverse.first(@limit_terms)
    term_set = terms.to_set
    @headers = terms.map { |term| { key: term, title: "#{term}期" } }
    return @rows = [] if terms.empty?

    values_map = Hash.new { |hash, key| hash[key] = 0.0 }
    records.where.not(value_numeric: nil).select(:id, :metric_label, :month, :value_numeric).find_each do |record|
      term = fiscal_term(record.month)
      next unless term_set.include?(term)

      normalized = canonical_label(record.metric_label)
      next unless target_labels.any? { |lbl| canonical_label(lbl) == normalized }

      values_map[[normalized, term]] += record.value_numeric.to_f
    end

    @rows = target_labels.reject { |label| SYSTEM_LABELS.include?(label) }.map do |label|
      canonical = canonical_label(label)
      {
        label: label,
        section_label: nil,
        row_type: classify_row(label, {}),
        values: @headers.map { |header| values_map[[canonical, header[:key]]] }
      }
    end
  end

  def base_scope
    scope = VehicleFinancialMetric.left_joins(:vehicle)
    scope = scope.where(vehicle_financial_metrics: { tenant_id: @tenant_id }) if @tenant_id
    scope = scope.where(vehicle_financial_metrics: { vehicle_code: @vehicle_codes }) if @vehicle_codes.present?
    scope = scope.where.not(vehicle_financial_metrics: { vehicle_code: [nil, ""] })
    scope = scope.where(vehicles: { depot_name: @depot }) if @depot.present? && @vehicle_codes.blank?
    scope = scope.where(vehicles: { shipper_name: @shipper }) if @shipper.present? && @vehicle_codes.blank?
    scope
  end

  def apply_month_range(scope)
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

  def fiscal_term(month)
    return nil unless month
    start_month = (@term_start_month || 9).to_i
    if month.month >= start_month
      month.year - 1949
    else
      (month.year - 1) - 1949
    end
  end

  def stop_label?(label)
    stripped = canonical_label(label)
    VehicleFinancialMatrix::STOP_LABEL_PATTERNS.any? { |pattern| stripped.match?(pattern) }
  end

  def normalize_label(label)
    label.to_s.delete("　").strip
  end

  def canonical_label(label)
    normalized = normalize_label(label)
    @label_aliases.each do |canonical, aliases|
      return normalize_label(canonical) if Array(aliases).map { |a| normalize_label(a) }.include?(normalized) || normalize_label(canonical) == normalized
    end
    normalized
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

  # 集計用の特殊コードを除外（これらは合計行・平均行の可能性が高い）
  def excluded_vehicle_codes
    %w[99999 88888 77777 9999 8888 7777]
  end
end
