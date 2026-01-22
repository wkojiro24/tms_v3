require 'csv'

class AttendanceImporter
  class ImportError < StandardError; end

  attr_reader :tenant, :results

  def initialize(tenant)
    @tenant = tenant
    @results = { imported: 0, updated: 0, skipped: 0, errors: [] }
  end

  # 日次勤怠CSVインポート（標準形式: 20201001_20201130.csv）
  def import_daily(file_path)
    csv_content = read_with_encoding(file_path)
    csv = CSV.parse(csv_content, headers: true)

    csv.each_with_index do |row, index|
      import_daily_row(row, index + 2)
    end

    results
  end

  # 月次集計CSVインポート（カスタム形式: custom_csv_20250901_20250930.csv）
  def import_monthly(file_path)
    csv_content = read_with_encoding(file_path)
    csv = CSV.parse(csv_content, headers: true)

    # ファイル名から年月を取得（(1)などの重複番号も許容）
    filename = File.basename(file_path)
    if filename =~ /custom_csv_(\d{4})(\d{2})\d{2}_(\d{4})(\d{2})\d{2}/
      year = $3.to_i
      month = $4.to_i
    else
      raise ImportError, "ファイル名から期間を特定できません: #{filename}"
    end

    csv.each_with_index do |row, index|
      import_monthly_row(row, year, month, index + 2)
    end

    results
  end

  # フォルダ内の全ファイルをインポート
  def import_folder(folder_path, type: :daily)
    pattern = type == :daily ? "20*.csv" : "custom_csv_*.csv"
    files = Dir.glob(File.join(folder_path, pattern)).sort

    files.each do |file|
      if type == :daily
        import_daily(file)
      else
        import_monthly(file)
      end
    end

    results
  end

  private

  def read_with_encoding(file_path)
    content = File.read(file_path, encoding: 'Shift_JIS:UTF-8')
    content.encode('UTF-8', invalid: :replace, undef: :replace)
  rescue Encoding::InvalidByteSequenceError, Encoding::UndefinedConversionError
    # フォールバック: CP932で試す
    content = File.read(file_path, encoding: 'CP932:UTF-8')
    content.encode('UTF-8', invalid: :replace, undef: :replace)
  end

  def import_daily_row(row, line_number)
    employee_code = row['従業員コード']&.strip
    return if employee_code.blank?

    date_str = row['日時']&.strip
    return if date_str.blank?

    # 日付パース: "2020/10/01(木)" 形式
    work_date = parse_date(date_str)
    return unless work_date

    record = AttendanceRecord.find_or_initialize_by(
      tenant: tenant,
      employee_code: employee_code,
      work_date: work_date
    )

    is_new = record.new_record?

    record.assign_attributes(
      employee_name: row['名前']&.strip,
      day_type: row['勤務日種別']&.strip,
      time_zone_category: row['時間帯区分名']&.strip,
      pattern_name: row['パターン名']&.strip,
      clock_in: parse_time(row['出勤時刻(時刻のみ)']&.strip),
      clock_out: parse_time(row['退勤時刻(時刻のみ)']&.strip),
      work_location: row['備考(スケジュール)']&.strip,
      break_hours: parse_decimal(row['休憩時間']&.strip)
    )

    # 従業員との紐付け
    link_employee(record)

    if record.save
      is_new ? @results[:imported] += 1 : @results[:updated] += 1
    else
      @results[:errors] << "行#{line_number}: #{record.errors.full_messages.join(', ')}"
      @results[:skipped] += 1
    end
  rescue => e
    @results[:errors] << "行#{line_number}: #{e.message}"
    @results[:skipped] += 1
  end

  def import_monthly_row(row, year, month, line_number)
    employee_code = row['従業員コード']&.strip
    return if employee_code.blank?

    record = AttendanceMonthly.find_or_initialize_by(
      tenant: tenant,
      employee_code: employee_code,
      year: year,
      month: month
    )

    is_new = record.new_record?

    record.assign_attributes(
      employee_name: row['名前']&.strip,
      department_name: row['所属名']&.strip,
      working_days: parse_decimal(row['平日出勤日数']),
      holiday_working_days: parse_decimal(row['法定休日出勤日数']),
      substitute_days: parse_decimal(row['代休取得日数']),
      extra_holiday_days: parse_decimal(row['法定外休日出勤日数']),
      paid_leave_days: parse_decimal(row['有休取得日数']),
      absent_days: parse_decimal(row['欠勤取得日数']),
      total_hours: parse_decimal(row['拘束時間']),
      break_hours: parse_decimal(row['休憩時間']),
      overtime_hours: parse_decimal(row['平日残業']),
      holiday_hours: parse_decimal(row['法定休日時間']),
      extra_holiday_hours: parse_decimal(row['法定外休時間']),
      substitute_holiday_hours: parse_decimal(row['法定代休時間']),
      extra_substitute_hours: parse_decimal(row['法定外代時間']),
      scheduled_overtime: parse_decimal(row['所定内 残業']),
      paid_leave_hours: parse_decimal(row['有給休暇時間']),
      late_night_hours: parse_decimal(row['深夜残業'])
    )

    # 従業員との紐付け
    link_employee(record)

    if record.save
      is_new ? @results[:imported] += 1 : @results[:updated] += 1
    else
      @results[:errors] << "行#{line_number}: #{record.errors.full_messages.join(', ')}"
      @results[:skipped] += 1
    end
  rescue => e
    @results[:errors] << "行#{line_number}: #{e.message}"
    @results[:skipped] += 1
  end

  def parse_date(str)
    return nil if str.blank?
    # "2020/10/01(木)" -> Date
    if str =~ /(\d{4})\/(\d{1,2})\/(\d{1,2})/
      Date.new($1.to_i, $2.to_i, $3.to_i)
    else
      nil
    end
  end

  def parse_time(str)
    return nil if str.blank?
    # "08:50" -> Time
    if str =~ /(\d{1,2}):(\d{2})/
      Time.zone.parse("#{$1}:#{$2}")
    else
      nil
    end
  end

  def parse_decimal(str)
    return nil if str.blank?
    str.to_s.gsub(',', '').to_d
  rescue
    nil
  end

  def link_employee(record)
    employee = tenant.employees.find_by(employee_code: record.employee_code)
    record.employee = employee if employee
  end
end
