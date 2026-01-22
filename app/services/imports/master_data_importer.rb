require "roo"

module Imports
  class MasterDataImporter
    COLUMN_MAPPINGS = {
      destinations: {
        "届け先コード" => :code,
        "届け先名" => :name,
        "郵便番号" => :postal_code,
        "住所" => :address,
        "電話番号" => :phone,
        "荷主コード" => :shipper_code,
        "備考" => :notes
      },
      shippers: {
        "荷主コード" => :code,
        "荷主名" => :name,
        "郵便番号" => :postal_code,
        "住所" => :address,
        "電話番号" => :phone,
        "FAX" => :fax,
        "担当者名" => :contact_name,
        "請求締日" => :billing_closing_day,
        "支払サイト" => :payment_terms,
        "備考" => :notes
      },
      subcontractors: {
        "傭車先コード" => :code,
        "会社名" => :name,
        "郵便番号" => :postal_code,
        "住所" => :address,
        "電話番号" => :phone,
        "FAX" => :fax,
        "担当者名" => :contact_name,
        "単価区分" => :rate_category,
        "備考" => :notes
      },
      route_distances: {
        "出発地コード" => :origin_code,
        "到着地コード" => :destination_code,
        "距離(km)" => :distance_km,
        "所要時間(分)" => :duration_minutes,
        "備考" => :notes
      },
      tariffs: {
        "タリフコード" => :code,
        "荷主コード" => :shipper_code,
        "出発地" => :origin,
        "到着地" => :destination,
        "車格" => :vehicle_class,
        "重量区分" => :weight_category,
        "単価" => :unit_price,
        "有効開始日" => :effective_from,
        "有効終了日" => :effective_until,
        "備考" => :notes
      },
      employees: {
        "社員番号" => :employee_code,
        "姓" => :last_name,
        "名" => :first_name,
        "姓カナ" => :last_name_kana,
        "名カナ" => :first_name_kana,
        "生年月日" => :date_of_birth,
        "入社日" => :hire_date,
        "部門コード" => :department_code,
        "職種コード" => :job_category_code,
        "役職コード" => :job_position_code,
        "雇用形態" => :employment_type,
        "メール" => :email,
        "電話番号" => :phone
      },
      vehicles: {
        "車両番号" => :number,
        "車格" => :vehicle_class,
        "メーカー" => :manufacturer,
        "車種" => :model,
        "年式" => :model_year,
        "初度登録日" => :first_registration_date,
        "車検満了日" => :inspection_due_date,
        "ステータス" => :status,
        "担当ドライバー" => :driver_code,
        "備考" => :notes
      },
      vehicle_aliases: {
        "車両番号" => :vehicle_number,
        "エイリアス" => :alias_name,
        "説明" => :description
      },
      attendance: {
        "社員番号" => :employee_code,
        "日付" => :work_date,
        "出勤時刻" => :clock_in,
        "退勤時刻" => :clock_out,
        "休憩時間(分)" => :break_minutes,
        "時間外(分)" => :overtime_minutes,
        "深夜(分)" => :night_minutes,
        "備考" => :notes
      },
      account_codes: {
        "科目コード" => :code,
        "科目名" => :name,
        "科目区分" => :category,
        "親科目コード" => :parent_code,
        "表示順" => :display_order,
        "備考" => :notes
      }
    }.freeze

    MODEL_CLASSES = {
      destinations: "Destination",
      shippers: "Shipper",
      subcontractors: "SubcontractorCompany",
      route_distances: "RouteDistance",
      tariffs: "Tariff",
      employees: "Employee",
      vehicles: "Vehicle",
      vehicle_aliases: "VehicleAlias",
      attendance: "AttendanceRecord",
      account_codes: "AccountCode"
    }.freeze

    attr_reader :tenant, :file, :data_type, :dry_run, :overwrite, :uploaded_by

    def initialize(tenant:, file:, data_type:, dry_run: false, overwrite: false, uploaded_by: nil)
      @tenant = tenant
      @file = file
      @data_type = data_type.to_sym
      @dry_run = dry_run
      @overwrite = overwrite
      @uploaded_by = uploaded_by
    end

    def call
      created = updated = skipped = 0
      warnings = []
      errors = []

      spreadsheet = open_spreadsheet
      sheet = spreadsheet.sheet(0)

      headers = extract_headers(sheet)
      column_mapping = build_column_mapping(headers)

      if column_mapping.empty?
        return {
          status: :error,
          message: "ヘッダー行が見つかりませんでした",
          created: 0,
          updated: 0,
          skipped: 0,
          warnings: [],
          errors: [{ message: "ヘッダー行が見つかりません" }]
        }
      end

      batch = create_import_batch unless dry_run

      ActiveRecord::Base.transaction do
        (header_row_index + 1).upto(sheet.last_row) do |row_idx|
          row = Array(sheet.row(row_idx))
          next if row.compact.blank?

          attrs = extract_attributes(row, column_mapping)
          next if attrs.values.all?(&:blank?)

          begin
            result = upsert_record(attrs)
            case result
            when :created
              created += 1
            when :updated
              updated += 1
            when :skipped
              skipped += 1
            end
          rescue ActiveRecord::RecordInvalid => e
            errors << { message: "行#{row_idx}: #{e.message}", row: row_idx }
            skipped += 1
          rescue StandardError => e
            errors << { message: "行#{row_idx}: #{e.message}", row: row_idx }
            skipped += 1
          end
        end

        raise ActiveRecord::Rollback if dry_run
      end

      update_batch_status(batch, created, updated, skipped, errors) unless dry_run

      {
        status: errors.any? ? :partial : :success,
        created: created,
        updated: updated,
        skipped: skipped,
        warnings: warnings,
        errors: errors
      }
    rescue StandardError => e
      Rails.logger.error("[MasterDataImporter] #{e.class}: #{e.message}")
      Rails.logger.error(e.backtrace.take(10).join("\n"))
      {
        status: :error,
        message: e.message,
        created: 0,
        updated: 0,
        skipped: 0,
        warnings: [],
        errors: [{ message: e.message }]
      }
    end

    private

    def open_spreadsheet
      temp_file = file.respond_to?(:tempfile) ? file.tempfile : file
      extension = File.extname(original_filename).delete(".")
      Roo::Spreadsheet.open(temp_file.path, extension: extension)
    end

    def original_filename
      if file.respond_to?(:original_filename)
        file.original_filename
      else
        File.basename(file.to_s)
      end
    end

    def header_row_index
      @header_row_index ||= 1
    end

    def extract_headers(sheet)
      1.upto([10, sheet.last_row].min) do |row_idx|
        row = Array(sheet.row(row_idx)).map { |v| v.to_s.strip }
        expected_headers = COLUMN_MAPPINGS[data_type]&.keys || []
        if row.any? { |h| expected_headers.include?(h) }
          @header_row_index = row_idx
          return row
        end
      end
      Array(sheet.row(1)).map { |v| v.to_s.strip }
    end

    def build_column_mapping(headers)
      expected_mapping = COLUMN_MAPPINGS[data_type] || {}
      mapping = {}

      headers.each_with_index do |header, idx|
        next if header.blank?
        if field = expected_mapping[header]
          mapping[idx] = field
        end
      end

      mapping
    end

    def extract_attributes(row, column_mapping)
      attrs = {}
      column_mapping.each do |idx, field|
        value = row[idx]
        attrs[field] = normalize_value(field, value)
      end
      attrs
    end

    def normalize_value(field, value)
      return nil if value.nil?

      case field
      when :effective_from, :effective_until, :date_of_birth, :hire_date,
           :first_registration_date, :inspection_due_date, :work_date
        parse_date(value)
      when :distance_km
        value.to_f if value.present?
      when :duration_minutes, :unit_price, :display_order, :break_minutes,
           :overtime_minutes, :night_minutes, :model_year
        value.to_i if value.present?
      when :clock_in, :clock_out
        parse_time(value)
      else
        value.to_s.strip.presence
      end
    end

    def parse_date(value)
      return value if value.is_a?(Date)
      return value.to_date if value.respond_to?(:to_date)
      return nil if value.to_s.strip.blank?

      Date.parse(value.to_s)
    rescue ArgumentError
      nil
    end

    def parse_time(value)
      return value if value.is_a?(Time)
      return nil if value.to_s.strip.blank?

      if value.to_s.match?(/\A\d{1,2}:\d{2}\z/)
        value.to_s
      else
        Time.parse(value.to_s).strftime("%H:%M")
      end
    rescue ArgumentError
      nil
    end

    def upsert_record(attrs)
      model_class = MODEL_CLASSES[data_type]&.constantize
      return :skipped unless model_class

      case data_type
      when :destinations
        upsert_destination(attrs)
      when :shippers
        upsert_shipper(attrs)
      when :subcontractors
        upsert_subcontractor(attrs)
      when :route_distances
        upsert_route_distance(attrs)
      when :tariffs
        upsert_tariff(attrs)
      when :employees
        upsert_employee(attrs)
      when :vehicles
        upsert_vehicle(attrs)
      when :vehicle_aliases
        upsert_vehicle_alias(attrs)
      else
        :skipped
      end
    end

    def upsert_destination(attrs)
      shipper = nil
      if attrs[:shipper_code].present?
        shipper = tenant.shippers.find_by(code: attrs[:shipper_code])
      end

      record = tenant.destinations.find_or_initialize_by(code: attrs[:code])
      return :skipped if record.persisted? && !overwrite

      record.assign_attributes(
        name: attrs[:name],
        postal_code: attrs[:postal_code],
        address: attrs[:address],
        phone: attrs[:phone],
        shipper: shipper,
        notes: attrs[:notes]
      )

      was_new = record.new_record?
      record.save!
      was_new ? :created : :updated
    end

    def upsert_shipper(attrs)
      record = tenant.shippers.find_or_initialize_by(code: attrs[:code])
      return :skipped if record.persisted? && !overwrite

      record.assign_attributes(
        name: attrs[:name],
        postal_code: attrs[:postal_code],
        address: attrs[:address],
        phone: attrs[:phone],
        fax: attrs[:fax],
        contact_name: attrs[:contact_name],
        billing_closing_day: attrs[:billing_closing_day],
        payment_terms: attrs[:payment_terms],
        notes: attrs[:notes]
      )

      was_new = record.new_record?
      record.save!
      was_new ? :created : :updated
    end

    def upsert_subcontractor(attrs)
      record = tenant.subcontractor_companies.find_or_initialize_by(code: attrs[:code])
      return :skipped if record.persisted? && !overwrite

      record.assign_attributes(
        name: attrs[:name],
        postal_code: attrs[:postal_code],
        address: attrs[:address],
        phone: attrs[:phone],
        fax: attrs[:fax],
        contact_name: attrs[:contact_name],
        rate_category: attrs[:rate_category],
        notes: attrs[:notes]
      )

      was_new = record.new_record?
      record.save!
      was_new ? :created : :updated
    end

    def upsert_route_distance(attrs)
      record = tenant.route_distances.find_or_initialize_by(
        origin_code: attrs[:origin_code],
        destination_code: attrs[:destination_code]
      )
      return :skipped if record.persisted? && !overwrite

      record.assign_attributes(
        distance_km: attrs[:distance_km],
        duration_minutes: attrs[:duration_minutes],
        notes: attrs[:notes]
      )

      was_new = record.new_record?
      record.save!
      was_new ? :created : :updated
    end

    def upsert_tariff(attrs)
      shipper = nil
      if attrs[:shipper_code].present?
        shipper = tenant.shippers.find_by(code: attrs[:shipper_code])
      end

      record = tenant.tariffs.find_or_initialize_by(code: attrs[:code])
      return :skipped if record.persisted? && !overwrite

      record.assign_attributes(
        shipper: shipper,
        origin: attrs[:origin],
        destination: attrs[:destination],
        vehicle_class: attrs[:vehicle_class],
        weight_category: attrs[:weight_category],
        unit_price: attrs[:unit_price],
        effective_from: attrs[:effective_from],
        effective_until: attrs[:effective_until],
        notes: attrs[:notes]
      )

      was_new = record.new_record?
      record.save!
      was_new ? :created : :updated
    end

    def upsert_employee(attrs)
      record = Employee.find_or_initialize_by(employee_code: attrs[:employee_code])
      return :skipped if record.persisted? && !overwrite

      record.assign_attributes(
        last_name: attrs[:last_name],
        first_name: attrs[:first_name],
        last_name_kana: attrs[:last_name_kana],
        first_name_kana: attrs[:first_name_kana],
        date_of_birth: attrs[:date_of_birth],
        hire_date: attrs[:hire_date],
        current_status: "active"
      )

      was_new = record.new_record?
      record.save!
      was_new ? :created : :updated
    end

    def upsert_vehicle(attrs)
      record = Vehicle.find_or_initialize_by(number: attrs[:number])
      return :skipped if record.persisted? && !overwrite

      record.assign_attributes(
        vehicle_class: attrs[:vehicle_class],
        manufacturer: attrs[:manufacturer],
        model: attrs[:model],
        model_year: attrs[:model_year],
        first_registration_date: attrs[:first_registration_date],
        inspection_due_date: attrs[:inspection_due_date],
        status: attrs[:status] || "active",
        notes: attrs[:notes]
      )

      was_new = record.new_record?
      record.save!
      was_new ? :created : :updated
    end

    def upsert_vehicle_alias(attrs)
      vehicle = Vehicle.find_by(number: attrs[:vehicle_number])
      return :skipped unless vehicle

      record = VehicleAlias.find_or_initialize_by(
        vehicle: vehicle,
        alias_name: attrs[:alias_name]
      )
      return :skipped if record.persisted? && !overwrite

      record.description = attrs[:description] if attrs[:description].present?

      was_new = record.new_record?
      record.save!
      was_new ? :created : :updated
    end

    def create_import_batch
      tenant.import_batches.create!(
        source_file_name: original_filename,
        imported_at: Time.current,
        metadata: {
          import_type: data_type.to_s,
          status: "processing",
          uploaded_by_id: uploaded_by&.id
        }
      )
    end

    def update_batch_status(batch, created, updated, skipped, errors)
      return unless batch

      status = errors.any? ? "partial" : "completed"
      batch.update!(
        metadata: batch.metadata.merge(
          status: status,
          created: created,
          updated: updated,
          skipped: skipped,
          error_count: errors.count
        )
      )
    end
  end
end
