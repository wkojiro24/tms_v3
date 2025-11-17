module VehicleFinancialsHelper
  CODE_LABELS = %w[部門コード タイヤ本数].freeze
  TEXT_LABELS = %w[車番 部門名 ドライバー名 年式 車種名].freeze
  DIVIDER_LABELS = %w[輸送原価計 営業所損益 本社管理費].freeze

  def vehicle_financial_value(label, value)
    return "" if value.nil?
    return "-" if value.blank?
    return value.to_s if value.is_a?(String)

    label_text = normalized_label_text(label)
    label_downcase = label_text.downcase

    case
    when TEXT_LABELS.include?(label_text)
      value.to_s
    when CODE_LABELS.include?(label_text)
      value.to_i
    when distance_label?(label_downcase)
      number_with_precision(value, precision: 0, delimiter: ",", strip_insignificant_zeros: true)
    when label_text.include?("使用リットル")
      number_with_precision(value, precision: 1, delimiter: ",", strip_insignificant_zeros: true)
    when label_downcase.include?("km/l")
      number_with_precision(value, precision: 2, strip_insignificant_zeros: true)
    else
      formatted = number_with_delimiter(value.to_f.round)
      return wrap_negative(formatted, value) if value.is_a?(Numeric) && value.negative?

      formatted
    end
  end

  def vehicle_group_label(detail)
    safe_join([
      content_tag(:div, detail[:title], class: "fw-semibold"),
      (content_tag(:div, detail[:subtitle], class: "text-muted small") if detail[:subtitle].present?)
    ].compact)
  end

  def vehicle_financial_row_class(row)
    classes = ["vehicle-grid__row"]
    case row[:row_type]
    when :vehicle_header
      classes << "vehicle-grid__row--vehicle"
    when :grand_total
      classes << "vehicle-grid__row--grand"
    when :subtotal
      classes << "vehicle-grid__row--subtotal"
    when :section_header
      classes << "vehicle-grid__row--section"
    end
    classes << "vehicle-grid__row--divider" if DIVIDER_LABELS.include?(normalize_label_text(row[:label]))
    classes.join(" ")
  end

  def vehicle_financial_label_classes(row)
    "text-start"
  end

  def vehicle_financial_section_label(row)
    case row[:row_type]
    when :vehicle_header
      "車両情報"
    when :section_header
      row[:label]
    when :detail
      row[:section_label]
    else
      nil
    end
  end

  def vehicle_financial_detail_row?(row)
    section = row[:section_label].to_s
    section.present? && section != row[:label] && row[:row_type] != :vehicle_header
  end

  def vehicle_financial_row_summary(row)
    numeric_values = Array(row[:values]).select { |value| value.is_a?(Numeric) }
    return { total: nil, average: nil } if numeric_values.blank?

    total = numeric_values.sum
    average = numeric_values.any? ? (total / numeric_values.length) : nil
    { total: total, average: average }
  end

  private

  def normalized_label_text(label)
    label.to_s.unicode_normalize(:nfkc)
  rescue StandardError
    label.to_s
  end

  def normalize_label_text(label)
    label.to_s.unicode_normalize(:nfkc).gsub(/\s+/, "")
  rescue StandardError
    label.to_s.gsub(/\s+/, "")
  end

  def distance_label?(label_downcase)
    label_downcase.include?("走行km")
  end

  def wrap_negative(formatted, value)
    content_tag(:span, formatted, class: "text-danger fw-semibold", data: { numeric: value })
  end

  def vehicle_financial_query(extra = {})
    (request.query_parameters || {}).merge(extra).compact
  end
end
