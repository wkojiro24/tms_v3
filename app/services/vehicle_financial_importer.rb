class VehicleFinancialImporter
  DEFAULT_EXCLUDED_CODES = %w[9999 8888].freeze
  FINAL_LABEL = "損益".freeze
  MONTH_PATTERNS = [
    /(\d{4})\s*年\s*(\d{1,2})\s*月/,
    /(\d{4})\s*[\.\/](\d{1,2})/
  ].freeze

  attr_reader :path, :tenant, :exclude_codes, :sheet_index, :normalizer

  def initialize(path:, tenant: ActsAsTenant.current_tenant, exclude_codes: DEFAULT_EXCLUDED_CODES, sheet_index: 0)
    @path = Pathname.new(path)
    @tenant = tenant || Tenant.first
    raise ArgumentError, "tenant is required" unless @tenant

    @exclude_codes = Array(exclude_codes).map(&:to_s)
    @sheet_index = sheet_index
    @normalizer = VehicleNormalizer.new(@tenant)
  end

  # Class method for importing from uploaded file (ActionDispatch::Http::UploadedFile)
  def self.import_from_uploaded_file(uploaded_file, tenant: ActsAsTenant.current_tenant)
    # Rooはファイル拡張子で形式を判断するため、正しい拡張子を持つ一時ファイルを作成
    original_ext = File.extname(uploaded_file.original_filename)
    temp_file = Tempfile.new(["vehicle_financial_import", original_ext])
    temp_path = temp_file.path

    begin
      temp_file.binmode
      temp_file.write(uploaded_file.read)
      temp_file.close

      Rails.logger.info "[VehicleFinancialImporter] Processing: #{uploaded_file.original_filename}, temp_path: #{temp_path}, ext: #{original_ext}"

      importer = new(path: temp_path, tenant: tenant)
      count = importer.import!

      Rails.logger.info "[VehicleFinancialImporter] Result: #{count} records created"

      { created: count, updated: 0, skipped: 0, warnings: [], errors: [] }
    rescue StandardError => e
      Rails.logger.error "[VehicleFinancialImporter] Error: #{e.class} - #{e.message}"
      Rails.logger.error e.backtrace.first(5).join("\n")
      { created: 0, updated: 0, skipped: 0, warnings: [], errors: [e.message] }
    ensure
      File.unlink(temp_path) if temp_path && File.exist?(temp_path)
    end
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

    log_normalization_results(vehicles)

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
      raw_code = value.to_s.strip
      next if index.zero?
      next unless valid_vehicle_code?(raw_code)

      # 正規化されたコードを取得
      normalized_code = normalizer.normalize(raw_code) || raw_code
      next if exclude_codes.include?(normalized_code)

      result << { code: normalized_code, raw_code: raw_code, column: index + 1 }
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

        # 空白・エラーでもレコードを作成（状態を追跡するため）
        # ただし、値がなく、かつ blank でもない場合はスキップ
        cell_state = normalized[:cell_state]

        metadata = {
          row_index: row_num,
          column_index: vehicle[:column]
        }
        metadata[:section_label] = section_label if section_label.present?
        metadata[:original_value] = raw_value.to_s.truncate(100) if cell_state == "error"
        # 元の車番コードが正規化されたものと異なる場合は記録
        metadata[:raw_vehicle_code] = vehicle[:raw_code] if vehicle[:raw_code] != vehicle[:code]

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
          cell_state: cell_state,
          source_file: path.basename.to_s,
          metadata: metadata,
          created_at: timestamp,
          updated_at: timestamp
        }
      end

      # 損益行は値を取り込んだ上でそこで処理を終える
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
    # nil の場合は空白
    if value.nil?
      return { value_numeric: nil, value_text: nil, unit: nil, cell_state: "blank" }
    end

    # 数値型の場合
    if value.is_a?(Numeric)
      return { value_numeric: BigDecimal(value.to_s), value_text: nil, unit: nil, cell_state: "value" }
    end

    # DateTime/Time型の場合（Excelの時間データ）
    # Excelでは時間を1日=1.0として小数で表現するため、時間に変換
    if value.is_a?(DateTime) || value.is_a?(Time)
      # 1900-01-01からの経過を時間として解釈
      # Excelの時間は小数部分が時間を表す（例: 0.5 = 12時間）
      # DateTimeの場合、時間部分を抽出して時間数に変換
      hours = value.hour + (value.min / 60.0) + (value.sec / 3600.0)
      return { value_numeric: BigDecimal(hours.to_s), value_text: nil, unit: "時間", cell_state: "value" }
    end

    text = value.to_s.strip

    # 空文字の場合は空白
    if text.blank?
      return { value_numeric: nil, value_text: nil, unit: nil, cell_state: "blank" }
    end

    # エラー値の場合
    if text.match?(/\A#(DIV\/0!|N\/A|VALUE!|REF!|NAME\?|NUM!|NULL!)\z/i)
      return { value_numeric: nil, value_text: text, unit: nil, cell_state: "error" }
    end

    # 数値としてパース可能な場合
    numeric = parse_numeric(text)
    if numeric
      { value_numeric: numeric, value_text: nil, unit: detect_unit(text), cell_state: "value" }
    else
      { value_numeric: nil, value_text: text, unit: nil, cell_state: "value" }
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
    # VehicleNormalizerを使って車両を検索
    vehicle = normalizer.find_vehicle(vehicle_code)
    vehicle&.id
  end

  def log_normalization_results(vehicles)
    normalized_count = vehicles.count { |v| v[:raw_code] != v[:code] }
    matched_count = vehicles.count { |v| resolve_vehicle_id(v[:code]).present? }
    unmatched_count = vehicles.size - matched_count

    Rails.logger.info "[VehicleFinancialImporter] ファイル: #{path.basename}"
    Rails.logger.info "[VehicleFinancialImporter] 車両数: #{vehicles.size}, 正規化: #{normalized_count}, マッチ: #{matched_count}, 未マッチ: #{unmatched_count}"

    # 正規化された車番をログ出力
    vehicles.select { |v| v[:raw_code] != v[:code] }.each do |v|
      Rails.logger.debug "[VehicleFinancialImporter] 名寄せ: #{v[:raw_code]} → #{v[:code]}"
    end

    # 未マッチの車番をログ出力
    vehicles.reject { |v| resolve_vehicle_id(v[:code]).present? }.each do |v|
      Rails.logger.warn "[VehicleFinancialImporter] 未マッチ車番: #{v[:code]} (元: #{v[:raw_code]})"
    end
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
