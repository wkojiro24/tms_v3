class VehicleFinancialImporter
  DEFAULT_EXCLUDED_CODES = %w[9999 8888].freeze
  FINAL_LABEL = "損益".freeze
  MONTH_PATTERNS = [
    /(\d{4})\s*年\s*(\d{1,2})\s*月/,
    /(\d{4})\s*[\.\/](\d{1,2})/
  ].freeze

  attr_reader :path, :tenant, :exclude_codes, :sheet_index

  def initialize(path:, tenant: ActsAsTenant.current_tenant, exclude_codes: DEFAULT_EXCLUDED_CODES, sheet_index: 0)
    @path = Pathname.new(path)
    @tenant = tenant || Tenant.first
    raise ArgumentError, "tenant is required" unless @tenant

    @exclude_codes = Array(exclude_codes).map(&:to_s)
    @sheet_index = sheet_index
  end

  def import!
    raise Errno::ENOENT, "File not found #{path}" unless path.exist?

    workbook = Roo::Spreadsheet.open(path.to_s, extension: spreadsheet_extension)
    sheet = workbook.sheet(sheet_index)
    month = detect_month(sheet)
    header_row = find_header_row(sheet)
    raise ArgumentError, "車番ヘッダが見つかりません" unless header_row

    vehicles = extract_vehicle_columns(sheet.row(header_row))
    raise ArgumentError, "有効な車番が見つかりません" if vehicles.blank?

    metrics = build_metrics(sheet, header_row + 1, month, vehicles)
    persist_metrics(metrics, month)
    metrics.count
  end

  private

  def spreadsheet_extension
    ext = path.extname.delete(".").downcase
    ext = "xlsx" if ext.blank?
    ext.to_sym
  end

  def detect_month(sheet)
    (1..20).each do |row_num|
      sheet.row(row_num).compact.each do |cell|
        month = parse_month_from_string(cell.to_s)
        return month if month
      end
    end

    month_from_filename || raise(ArgumentError, "年月がヘッダから検出できません")
  end

  def find_header_row(sheet)
    (1..sheet.last_row).find do |row_num|
      sheet.row(row_num).compact.any? { |cell| cell.to_s.include?("車番") }
    end
  end

  def extract_vehicle_columns(row_data)
    row_data.each_with_index.with_object([]) do |(value, index), result|
      code = value.to_s.strip
      next if index.zero?
      next unless valid_vehicle_code?(code)
      next if exclude_codes.include?(code)

      result << { code:, column: index + 1 }
    end
  end

  def build_metrics(sheet, start_row, month, vehicles)
    timestamp = Time.current

    collection = []

    (start_row..sheet.last_row).each do |row_num|
      label_info = extract_row_labels(sheet, row_num)
      label = label_info[:label]
      section_label = label_info[:section_label]
      next if label.blank?

      metric_key = normalize_key(label)
      vehicles.each do |vehicle|
        raw_value = sheet.cell(row_num, vehicle[:column])
        normalized = normalize_value(raw_value)
        next if normalized[:value_numeric].nil? && normalized[:value_text].blank?

        metadata = {
          row_index: row_num,
          column_index: vehicle[:column]
        }
        metadata[:section_label] = section_label if section_label.present?

        collection << {
          tenant_id: tenant.id,
          vehicle_id: resolve_vehicle_id(vehicle[:code]),
          vehicle_code: vehicle[:code],
          month: month,
          metric_key: metric_key,
          metric_label: label,
          value_numeric: normalized[:value_numeric],
          value_text: normalized[:value_text],
          unit: normalized[:unit],
          source_file: path.basename.to_s,
          metadata: metadata,
          created_at: timestamp,
          updated_at: timestamp
        }
      end

      break if final_label?(label)
    end

    collection
  end

  def persist_metrics(rows, month)
    return if rows.blank?

    VehicleFinancialMetric.where(
      tenant: tenant,
      month: month,
      source_file: path.basename.to_s
    ).delete_all

    VehicleFinancialMetric.insert_all(rows)
  end

  def normalize_key(label)
    key = label.to_s.strip.gsub(/\s+/, "_")
    key.present? ? key : "metric"
  end

  def normalize_label(label)
    label.to_s.delete("　").strip
  end

  def final_label?(label)
    normalize_label(label) == FINAL_LABEL
  end

  def normalize_value(value)
    return { value_numeric: nil, value_text: nil, unit: nil } if value.nil?

    if value.is_a?(Numeric)
      { value_numeric: BigDecimal(value.to_s), value_text: nil, unit: nil }
    else
      text = value.to_s.strip
      return { value_numeric: nil, value_text: nil, unit: nil } if text.blank? || text == "#DIV/0!"

      numeric = parse_numeric(text)
      if numeric
        { value_numeric: numeric, value_text: nil, unit: detect_unit(text) }
      else
        { value_numeric: nil, value_text: text, unit: nil }
      end
    end
  end

  def parse_numeric(text)
    normalized = text.tr("０-９．－,", "0-9.-,")
    return unless normalized.match?(/\A[\d\.\-,\s]+\z/)

    cleaned = normalized.delete(",").strip
    return if cleaned.blank?

    BigDecimal(cleaned)
  rescue ArgumentError
    nil
  end

  def detect_unit(text)
    return "km/ℓ" if text.include?("km/ℓ")

    nil
  end

  def resolve_vehicle_id(vehicle_code)
    vehicle = Vehicle.find_by(call_sign: vehicle_code) ||
              Vehicle.find_by(registration_number: vehicle_code)

    vehicle&.id
  end

  def valid_vehicle_code?(code)
    return false if code.blank?
    return false if code.include?("車番")

    cleaned = code.delete("^0-9-")
    cleaned.present?
  end

  def parse_month_from_string(value)
    return excel_serial_to_date(value) if value.is_a?(Numeric)

    text = value.to_s.tr("０-９", "0-9").tr("／", "/").tr("．", ".").strip
    MONTH_PATTERNS.each do |pattern|
      if (match = text.match(pattern))
        year = match[1].to_i
        month = match[2].to_i
        return Date.new(year, month, 1) rescue nil
      end
    end

    if text.match?(/\A\d+(\.\d+)?\z/)
      serial = text.to_f
      return excel_serial_to_date(serial) if serial > 2000
    end

    nil
  end

  def excel_serial_to_date(serial)
    return nil if serial.nil?
    Date.new(1899, 12, 30) + serial.to_i
  rescue ArgumentError
    nil
  end

  def month_from_filename
    base = path.basename.to_s
    if (match = base.match(/(\d{2})(\d{2})/))
      year = 2000 + match[1].to_i
      month = match[2].to_i
      return Date.new(year, month, 1)
    end
    nil
  end

  def extract_row_labels(sheet, row_num)
    section = sheet.cell(row_num, 1)
    detail = sheet.cell(row_num, 2)

    section_text = section.to_s.strip
    detail_text = detail.to_s.strip

    label = detail_text.present? ? detail_text : section_text

    {
      label: label,
      section_label: section_text.presence
    }
  end
end
