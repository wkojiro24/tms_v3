require "bigdecimal"
require "roo"

module Imports
  class JournalImporter
    HEADER_PARENT_ROW = 3
    HEADER_CHILD_ROW = 4

    PRIMARY_FIELD_MAPPING = {
      "日付" => :date,
      "伝票No." => :slip_no,
      "仕訳番号" => :line_no,
      "摘要" => :memo,
      "勘定科目" => :debit_ac_name,
      "補助科目" => :vendor_name,
      "部門" => :dept_name,
      "金額" => :debit_amount,
      "借方|勘定科目" => :debit_ac_name,
      "借方|補助科目" => :vendor_name,
      "借方|部門" => :dept_name,
      "借方|金額" => :debit_amount,
      "貸方|勘定科目" => :credit_ac_name,
      "貸方|補助科目" => :credit_vendor_name,
      "貸方|部門" => :credit_dept_name,
      "貸方|金額" => :credit_amount
    }.freeze

    MEMO_LABELS = {
      "決算" => "決算",
      "付箋１" => "付箋1",
      "付箋2" => "付箋2",
      "生成元" => "生成元",
      "仕訳メモ" => "メモ"
    }.freeze

    DUPLICATE_METADATA_KEYS = {
      "debit_tax_category" => "credit_tax_category",
      "debit_tax_calc_type" => "credit_tax_calc_type",
      "debit_tax_amount" => "credit_tax_amount"
    }.freeze

    METADATA_MAPPING = {
      "借方|税区分" => "debit_tax_category",
      "借方|税計算区分" => "debit_tax_calc_type",
      "借方|消費税額" => "debit_tax_amount",
      "税区分" => "debit_tax_category",
      "税計算区分" => "debit_tax_calc_type",
      "消費税額" => "debit_tax_amount",
      "貸方|税区分" => "credit_tax_category",
      "貸方|税計算区分" => "credit_tax_calc_type",
      "貸方|消費税額" => "credit_tax_amount",
      "貸方|補助科目" => "credit_vendor_name",
      "貸方|部門" => "credit_dept_name",
      "請求書区分" => "invoice_category",
      "仕入税額控除" => "input_tax_credit",
      "期日" => "due_date",
      "番号" => "reference_number",
      "作業日付" => "processed_on"
    }.freeze

    attr_reader :tenant, :file_path, :source_file_name, :options

    def initialize(tenant:, file_path:, source_file_name:, options: {})
      @tenant = tenant
      @file_path = file_path
      @source_file_name = source_file_name
      @options = options
    end

    def call
      timestamp = Time.zone.now
      spreadsheet = Roo::Spreadsheet.open(file_path)
      target_period = build_period_range
      batch = find_or_initialize_batch(timestamp, target_period)

      entry_cache = {}

      spreadsheet.sheets.each do |sheet_name|
        sheet = spreadsheet.sheet(sheet_name)
        headers = build_headers(sheet)
        next if headers.compact.blank?
        row_context = {
          date: nil,
          slip_no: nil,
          document_type: nil
        }

        start_row = HEADER_CHILD_ROW + 1
        start_row.upto(sheet.last_row) do |row_index|
          values = sheet.row(row_index)
          next if values.compact.blank?

          row_attrs = normalize_row(headers, values, row_context)
          next unless row_attrs

          key = [
            row_attrs[:slip_no].presence || "NO-SLIP",
            row_attrs[:date],
            sheet_name
          ]

          entry = entry_cache[key]

          unless entry
            entry = tenant.journal_entries.build(
              import_batch: batch,
              entry_date: row_attrs[:date],
              slip_no: row_attrs[:slip_no],
              document_type: row_attrs[:document_type],
              source_sheet_name: sheet_name,
              source_start_row: row_index,
              source_end_row: row_index,
              summary: row_attrs[:memo],
              metadata: {
                "notes" => [],
                "line_numbers" => []
              }
            )
            entry_cache[key] = entry
          else
            entry.source_end_row = row_index
            entry.summary ||= row_attrs[:memo]
          end

          entry.metadata["line_numbers"] << row_attrs[:line_no] if row_attrs[:line_no]
          entry.metadata["notes"] << row_attrs[:memo] if row_attrs[:memo].present?

          build_debit_line(entry, row_attrs, row_index)
          build_credit_line(entry, row_attrs, row_index)
        end
      end

      entry_cache.values.each do |entry|
        entry.metadata["notes"] = Array(entry.metadata["notes"]).compact.uniq
        entry.metadata["line_numbers"] = Array(entry.metadata["line_numbers"]).compact.uniq
        entry.save!
      end

      batch
    end

    private

    def find_or_initialize_batch(timestamp, target_period)
      digest = options[:source_digest]
      metadata = options.fetch(:metadata, {})

      batch = if digest.present?
                tenant.import_batches.find_or_initialize_by(source_digest: digest)
      else
                tenant.import_batches.build
      end

      batch.source_file_name = source_file_name
      batch.imported_at = timestamp
      batch.metadata = (batch.metadata || {}).merge(metadata)
      batch.save!
      batch.journal_entries.destroy_all
      wipe_period_entries(batch, target_period) if target_period && replace_period?
      batch
    end

    def build_period_range
      start_param = options[:period_start] || options.dig(:metadata, :period_start)
      end_param = options[:period_end] || options.dig(:metadata, :period_end)
      return nil if start_param.blank? || end_param.blank?

      start_date = Date.parse("#{start_param}-01")
      end_date = Date.parse("#{end_param}-01").end_of_month
      start_date..end_date
    rescue ArgumentError
      nil
    end

    def replace_period?
      return options[:replace_period] unless options[:replace_period].nil?
      options[:period_start].present? && options[:period_end].present?
    end

    def wipe_period_entries(batch, period_range)
      tenant.journal_entries
            .where(entry_date: period_range)
            .where.not(import_batch_id: batch.id)
            .find_each(&:destroy!)

      tenant.import_batches
            .where.not(id: batch.id)
            .left_outer_joins(:journal_entries)
            .where(journal_entries: { id: nil })
            .find_each(&:destroy!)
    end

    def build_headers(sheet)
      parent_row = safe_row(sheet, HEADER_PARENT_ROW)
      child_row = safe_row(sheet, HEADER_CHILD_ROW)
      length = [parent_row.length, child_row.length].max
      section = nil # :debit, :credit

      Array.new(length) do |index|
        raw_parent = normalize_header(parent_row[index])
        raw_child = normalize_header(child_row[index])

        case raw_parent
        when "借方"
          section = :debit
        when "貸方"
          section = :credit
        when ""
          # keep current section
        else
          section = nil if raw_parent.present?
        end

        parent_label =
          case section
          when :debit
            "借方"
          when :credit
            "貸方"
          else
            raw_parent.presence
          end

        child_label = raw_child.presence

        if parent_label.present? && child_label.present?
          parent_label == child_label ? parent_label : "#{parent_label}|#{child_label}"
        elsif child_label.present?
          case section
          when :debit
            "借方|#{child_label}"
          when :credit
            "貸方|#{child_label}"
          else
            child_label
          end
        else
          parent_label
        end
      end
    end

    def safe_row(sheet, index)
      sheet.row(index).map { |value| value }
    rescue RangeError
      []
    end

    def normalize_header(value)
      value.to_s.strip
    end

    def normalize_row(headers, values, context = nil)
      attrs = {
        metadata: {}
      }
      memo_parts = []

      headers.each_with_index do |header, idx|
        next if header.blank?
        raw_value = values[idx]
        next if raw_value.nil? || raw_value.to_s.strip.blank?

        if header == "タイプ"
          attrs[:document_type] = raw_value.to_s.strip
          next
        end

        if field = PRIMARY_FIELD_MAPPING[header]
          assign_primary_field(attrs, memo_parts, field, raw_value, header)
        elsif metadata_key = METADATA_MAPPING[header]
          metadata_value = normalized_metadata_value(metadata_key, raw_value)
          if attrs[:metadata].key?(metadata_key) && DUPLICATE_METADATA_KEYS[metadata_key]
            attrs[:metadata][DUPLICATE_METADATA_KEYS[metadata_key]] = metadata_value
          else
            attrs[:metadata][metadata_key] = metadata_value
          end
        elsif MEMO_LABELS.key?(header)
          label = MEMO_LABELS[header]
          memo_parts << "#{label}: #{raw_value}"
        end
      end

      attrs[:memo] = memo_parts.join(" / ") if memo_parts.any?
      attrs[:metadata].compact!

      attrs[:date] = attrs[:date] || attrs[:metadata].delete("processed_on")&.then { |value| parse_date(value) }

      if context
        attrs[:date] ||= context[:date]
        attrs[:slip_no] ||= context[:slip_no]
        attrs[:document_type] ||= context[:document_type]
      end

      return nil if attrs[:date].blank?
      return nil if attrs[:debit_amount].blank? && attrs[:credit_amount].blank?

      normalize_credit_only_row(attrs)

      if context
        context[:date] = attrs[:date] if attrs[:date].present?
        context[:slip_no] = attrs[:slip_no] if attrs[:slip_no].present?
        context[:document_type] = attrs[:document_type] if attrs[:document_type].present?
      end

      attrs
    end

    def assign_primary_field(attrs, memo_parts, field, raw_value, header)
      case field
      when :date
        attrs[:date] = parse_date(raw_value)
      when :credit_amount
        attrs[:credit_amount] = parse_amount(raw_value)
      when :debit_amount
        attrs[:debit_amount] = parse_amount(raw_value)
      when :memo
        memo_parts << raw_value.to_s.strip
      when :credit_vendor_name
        value = raw_value.to_s.strip
        if attrs[:metadata]["credit_vendor_name"].present?
          attrs[:vendor_name] ||= value
        else
          attrs[:metadata]["credit_vendor_name"] = value
        end
      when :credit_dept_name
        value = raw_value.to_s.strip
        if attrs[:metadata]["credit_dept_name"].present?
          attrs[:dept_name] ||= value
        else
          attrs[:metadata]["credit_dept_name"] = value
        end
      when :debit_ac_name
        value = raw_value.to_s.strip
        if attrs[:debit_ac_name].present?
          attrs[:credit_ac_name] = value
        else
          attrs[:debit_ac_name] = value
        end
      when :vendor_name
        value = raw_value.to_s.strip
        if attrs[:vendor_name].present?
          attrs[:metadata]["credit_vendor_name"] = value
        else
          attrs[:vendor_name] = value
        end
      when :dept_name
        value = raw_value.to_s.strip
        if attrs[:dept_name].present?
          attrs[:metadata]["credit_dept_name"] = value
        else
          attrs[:dept_name] = value
        end
      else
        attrs[field] = raw_value.to_s.strip
      end
    end

    def normalized_metadata_value(key, raw_value)
      case key
      when "debit_tax_amount", "credit_tax_amount"
        parse_amount(raw_value)
      when "due_date", "processed_on"
        value = parse_date(raw_value)
        value&.to_s
      else
        raw_value.to_s.strip
      end
    end

    def parse_date(value)
      return value.to_date if value.respond_to?(:to_date)
      text = value.to_s.strip
      return if text.blank?

      if (match = text.match(/\A令和(?<year>\d+)年(?<month>\d+)月(?<day>\d+)日\z/))
        year = 2018 + match[:year].to_i
        Date.new(year, match[:month].to_i, match[:day].to_i)
      elsif (match = text.match(/\A平成(?<year>\d+)年(?<month>\d+)月(?<day>\d+)日\z/))
        year = 1988 + match[:year].to_i
        Date.new(year, match[:month].to_i, match[:day].to_i)
      elsif text.match?(/\A\d{4}[\/\-]\d{1,2}[\/\-]\d{1,2}\z/)
        Date.parse(text)
      elsif text.match?(/\A\d{1,2}月\d{1,2}日\z/)
        year = options[:default_year] || Time.zone.today.year
        Date.parse("#{year}年#{text}")
      else
        Date.parse(text)
      end
    rescue ArgumentError
      nil
    end

    def parse_amount(value)
      case value
      when Numeric
        value.to_i
      else
        text = value.to_s.tr(",", "").strip
        return if text.blank?

        BigDecimal(text).to_i
      end
    rescue ArgumentError
      nil
    end

    def build_debit_line(entry, attrs, row_index)
      amount = attrs[:debit_amount]
      return if amount.blank?

      account_name = attrs[:debit_ac_name]
      return if account_name.blank?

      entry.journal_lines.build(
        side: "debit",
        account_name: account_name,
        sub_account_name: attrs[:vendor_name],
        dept_name: attrs[:dept_name],
        vendor_name: attrs[:vendor_name],
        amount: amount,
        tax_amount: attrs[:metadata]["debit_tax_amount"],
        tax_category: attrs[:metadata]["debit_tax_category"],
        tax_calculation: attrs[:metadata]["debit_tax_calc_type"],
        memo: attrs[:memo],
        source_row_number: row_index,
        metadata: build_line_metadata(attrs, "debit")
      )
    end

    def build_credit_line(entry, attrs, row_index)
      amount = attrs[:credit_amount]
      return if amount.blank?

      account_name = attrs[:credit_ac_name]
      return if account_name.blank?

      dept_name = attrs[:metadata]["credit_dept_name"] || attrs[:dept_name]
      vendor_name = attrs[:metadata]["credit_vendor_name"]

      entry.journal_lines.build(
        side: "credit",
        account_name: account_name,
        sub_account_name: attrs[:metadata]["credit_vendor_name"],
        dept_name: dept_name,
        vendor_name: vendor_name,
        amount: amount,
        tax_amount: attrs[:metadata]["credit_tax_amount"],
        tax_category: attrs[:metadata]["credit_tax_category"],
        tax_calculation: attrs[:metadata]["credit_tax_calc_type"],
        memo: attrs[:memo],
        source_row_number: row_index,
        metadata: build_line_metadata(attrs, "credit")
      )
    end

    def build_line_metadata(attrs, side)
      base_metadata = {
        "invoice_category" => attrs[:metadata]["invoice_category"],
        "input_tax_credit" => attrs[:metadata]["input_tax_credit"],
        "due_date" => attrs[:metadata]["due_date"],
        "reference_number" => attrs[:metadata]["reference_number"],
        "line_no" => attrs[:line_no]
      }.compact

      if side == "debit"
        base_metadata.merge(
          "tax_category" => attrs[:metadata]["debit_tax_category"],
          "tax_calculation" => attrs[:metadata]["debit_tax_calc_type"]
        ).compact
      else
        base_metadata.merge(
          "tax_category" => attrs[:metadata]["credit_tax_category"],
          "tax_calculation" => attrs[:metadata]["credit_tax_calc_type"]
        ).compact
      end
    end

    def normalize_credit_only_row(attrs)
      return unless attrs[:credit_amount].present?
      return if attrs[:debit_amount].present?

      if attrs[:credit_ac_name].blank? && attrs[:debit_ac_name].present?
        attrs[:credit_ac_name] = attrs[:debit_ac_name]
        attrs[:debit_ac_name] = nil
      end

      if attrs[:metadata]["credit_vendor_name"].blank? && attrs[:vendor_name].present?
        attrs[:metadata]["credit_vendor_name"] = attrs[:vendor_name]
      end

      if attrs[:metadata]["credit_dept_name"].blank? && attrs[:dept_name].present?
        attrs[:metadata]["credit_dept_name"] = attrs[:dept_name]
      end
    end
  end
end
