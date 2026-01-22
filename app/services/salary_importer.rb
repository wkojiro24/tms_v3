require 'roo'

class SalaryImporter
  class ImportError < StandardError; end

  # 項目名とDBカラムのマッピング
  ITEM_MAPPING = {
    # 勤怠関連
    '平日出勤日数' => :working_days,
    '有休日数' => :paid_leave_days,
    '就労時間' => :working_hours,
    '有給休暇時間' => :paid_leave_hours,
    '有休残日数' => :paid_leave_remaining,
    '法定休日' => :statutory_holiday_days,
    '法定外休日' => :non_statutory_holiday_days,
    '欠勤日数' => :absence_days,
    '法定休日時間' => :statutory_holiday_hours,
    '法定外休時間' => :non_statutory_holiday_hours,
    # 支給項目（基準内賃金）
    '基本給' => :basic_salary,
    '職位加算' => :position_allowance,
    '職責加算' => :role_allowance,
    '大都市加算' => :city_allowance,
    '調整給' => :adjustment_salary,
    '基本給2' => :basic_salary_2,
    '役員報酬' => :executive_salary,
    # 支給項目（基準外賃金）
    '無事故加算' => :safety_bonus,
    '調整加算' => :adjustment_allowance,
    '有給休暇' => :paid_leave_pay,
    '欠勤控除' => :absence_deduction,
    # 残業関連（金額）
    '平日残業' => :weekday_overtime_pay,
    '法定休日残業' => :statutory_holiday_pay,
    '法定外休日残' => :non_statutory_holiday_pay,
    '法定代休残業' => :substitute_holiday_pay,
    '割増残業' => :premium_overtime_pay,
    '深夜残業' => :late_night_pay,
    '課税支給合計' => :taxable_total,
    '非課税通勤費' => :commuting_allowance,
    '非税支給合計' => :nontaxable_total,
    '支給合計' => :gross_total,
    # 控除項目
    '健康保険料' => :health_insurance,
    '介護保険料' => :nursing_insurance,
    '厚生年金保険' => :pension_insurance,
    '雇用保険料' => :employment_insurance,
    '社保料調整' => :social_insurance_adjustment,
    '社会保険料計' => :social_insurance_total,
    '所得税' => :income_tax,
    '組合費' => :union_fee,
    '住民税' => :resident_tax,
    '控除合計' => :deduction_total,
    # 計算結果
    '課税対象額' => :taxable_income,
    '差引支給合計' => :net_total,
    '現金支給額' => :cash_payment,
    '振込支給額' => :bank_transfer,
    # その他
    '扶養人数' => :dependents_count,
    '税額表' => :tax_table
  }.freeze

  # 拠点名のマッピング
  LOCATION_MAPPING = {
    '本社' => '本社',
    '小名浜' => '小名浜',
    '仙台' => '仙台',
    '川崎' => '川崎',
    '東京' => '東京',
    '九州' => '九州'
  }.freeze

  attr_reader :tenant, :results

  def initialize(tenant)
    @tenant = tenant
    @results = { imported: 0, updated: 0, skipped: 0, errors: [] }
  end

  # 単一ファイルをインポート
  def import_file(file_path)
    filename = File.basename(file_path)
    year, month, payment_type, location = parse_filename(filename)

    xlsx = Roo::Excelx.new(file_path)
    xlsx.default_sheet = xlsx.sheets.first

    # ヘッダー行を特定（従業員コードと名前）
    code_row, name_row, data_start_col = find_header_rows(xlsx)
    return results if code_row.nil?

    # 従業員コードと名前を取得
    employees = extract_employees(xlsx, code_row, name_row, data_start_col)

    # 項目行をマッピング
    item_rows = build_item_row_mapping(xlsx, name_row)

    # 各従業員のデータをインポート
    employees.each do |emp|
      import_employee_data(xlsx, emp, item_rows, year, month, payment_type, location)
    end

    results
  rescue => e
    @results[:errors] << "#{File.basename(file_path)}: #{e.message}"
    results
  end

  # フォルダ内の全ファイルをインポート
  def import_folder(folder_path)
    files = Dir.glob(File.join(folder_path, '**', '*.xlsx')).sort

    files.each do |file|
      next if File.basename(file).start_with?('~$')  # 一時ファイルをスキップ
      import_file(file)
    end

    results
  end

  private

  def parse_filename(filename)
    # 通常給与: 2025.08給与支給控除一覧表　本社②.xlsx
    # 賞与: 2022夏期賞与支給控除一覧表　本社.xlsx
    # 賞与(冬): 2022冬期賞与支給控除一覧表(年調含む)　本社.xlsx

    location = nil
    LOCATION_MAPPING.each do |key, value|
      if filename.include?(key)
        location = value
        break
      end
    end

    if filename =~ /(\d{4})\.(\d{2})給与/
      # 通常給与（新形式）: 2025.08給与支給控除一覧表
      year = $1.to_i
      month = $2.to_i
      payment_type = 'regular'
    elsif filename =~ /(\d{4})\.(\d{1,2})\.?給与/
      # 通常給与（1桁月）: 2023.1給与 or 2023.3.給与
      year = $1.to_i
      month = $2.to_i
      payment_type = 'regular'
    elsif filename =~ /(\d{4})\.(\d{1,2})月[分給]/
      # 通常給与（月分形式）: 2023.7月給与 or 2023.10月分給与
      year = $1.to_i
      month = $2.to_i
      payment_type = 'regular'
    elsif filename =~ /(\d{4})(\d{2})給与/
      # 通常給与（旧形式）: 202003給与支給控除一覧表
      year = $1.to_i
      month = $2.to_i
      payment_type = 'regular'
    elsif filename =~ /(\d{4})(\d{2})支給控除/
      # 通常給与（別形式）: 202108支給控除一覧表
      year = $1.to_i
      month = $2.to_i
      payment_type = 'regular'
    elsif filename =~ /(\d{4})[１1]月分給与/
      # 全角1月: 2024１月分給与
      year = $1.to_i
      month = 1
      payment_type = 'regular'
    elsif filename =~ /(\d{4})[\.\s年度]*夏[期季]賞与/
      year = $1.to_i
      month = 7  # 夏季賞与は7月として記録
      payment_type = 'summer_bonus'
    elsif filename =~ /(\d{4})[\.\s年度]*冬[期季]賞与/
      year = $1.to_i
      month = 12  # 冬季賞与は12月として記録
      payment_type = 'winter_bonus'
    else
      raise ImportError, "ファイル名から期間を特定できません: #{filename}"
    end

    [year, month, payment_type, location]
  end

  def find_header_rows(xlsx)
    # 従業員コード行を探す（4桁の数字が並んでいる行）
    (1..20).each do |row|
      cells = (1..xlsx.last_column).map { |col| xlsx.cell(row, col) }

      # 4桁の従業員コードを探す
      codes = cells.select { |c| c.to_s =~ /^\d{4}$/ }
      if codes.size >= 1
        # データ開始列を特定（最初の従業員コードの列）
        data_start_col = cells.index { |c| c.to_s =~ /^\d{4}$/ } + 1
        return [row, row + 1, data_start_col]
      end
    end

    nil
  end

  def extract_employees(xlsx, code_row, name_row, data_start_col)
    employees = []

    (data_start_col..xlsx.last_column).each do |col|
      code = xlsx.cell(code_row, col).to_s.strip
      name = xlsx.cell(name_row, col).to_s.strip

      # 4桁の従業員コードのみ対象（小計、合計などをスキップ）
      next unless code =~ /^\d{4}$/
      next if name.include?('計') || name.include?('名')

      employees << { code: code, name: name, col: col }
    end

    employees
  end

  def build_item_row_mapping(xlsx, name_row)
    mapping = {}
    item_col = find_item_column(xlsx, name_row)

    ((name_row + 1)..xlsx.last_row).each do |row|
      item_name = xlsx.cell(row, item_col).to_s.strip
      next if item_name.blank?

      db_column = ITEM_MAPPING[item_name]
      mapping[row] = { name: item_name, column: db_column } if db_column
    end

    mapping
  end

  def find_item_column(xlsx, name_row)
    # 「項目名」というヘッダーを探す
    (1..xlsx.last_column).each do |col|
      cell = xlsx.cell(name_row, col).to_s.strip
      return col if cell == '項目名'
    end

    # 見つからない場合は2列目を返す
    2
  end

  def import_employee_data(xlsx, emp, item_rows, year, month, payment_type, location)
    record = SalaryMonthly.find_or_initialize_by(
      tenant: tenant,
      employee_code: emp[:code],
      year: year,
      month: month,
      payment_type: payment_type
    )

    is_new = record.new_record?

    attributes = {
      employee_name: emp[:name],
      location: location
    }

    # 各項目の値を取得
    item_rows.each do |row, item_info|
      value = xlsx.cell(row, emp[:col])
      db_column = item_info[:column]

      # 値を適切な型に変換
      converted_value = convert_value(value, db_column)
      attributes[db_column] = converted_value if converted_value.present?
    end

    record.assign_attributes(attributes)

    # 従業員との紐付け
    link_employee(record)

    if record.save
      is_new ? @results[:imported] += 1 : @results[:updated] += 1
    else
      @results[:errors] << "#{emp[:code]}: #{record.errors.full_messages.join(', ')}"
      @results[:skipped] += 1
    end
  rescue => e
    @results[:errors] << "#{emp[:code]}: #{e.message}"
    @results[:skipped] += 1
  end

  def convert_value(value, column)
    return nil if value.nil?

    # 文字列カラム
    if column == :tax_table
      return value.to_s.strip
    end

    # 日時オブジェクト（Excelの時間セル）は無視
    # 時間カラム（_hours）に日時が入っている場合はnilを返す
    if value.is_a?(DateTime) || value.is_a?(Time)
      return nil
    end

    # 数値カラム
    if value.is_a?(Numeric)
      return value.to_i if column.to_s.end_with?('_salary', '_allowance', '_pay', '_total', '_insurance', '_adjustment', '_tax', '_income', '_payment', '_transfer', '_deduction')
      return value.to_d
    end

    # 文字列から数値を抽出
    str = value.to_s.gsub(',', '').strip
    return nil if str.blank? || str == '0'

    if str =~ /^[\d.]+$/
      num = str.to_d
      return num.to_i if column.to_s.end_with?('_salary', '_allowance', '_pay', '_total', '_insurance', '_adjustment', '_tax', '_income', '_payment', '_transfer', '_deduction')
      return num
    end

    nil
  end

  def link_employee(record)
    employee = tenant.employees.find_by(employee_code: record.employee_code)
    record.employee = employee if employee
  end
end
