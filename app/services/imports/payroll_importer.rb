require "roo"
require "securerandom"
require "time"

module Imports
  class PayrollImporter
    Result = Struct.new(
      :created, :updated, :skipped, :warnings, :errors,
      :period_from_file, :period_mode,
      keyword_init: true
    ) do
      def hard_error? = errors.any? { |e| e[:hard] }

      def to_h
        {
          created:,
          updated:,
          skipped:,
          warnings:,
          errors:,
          period_from_file: period_from_file&.strftime("%Y-%m"),
          period_mode:
        }
      end
    end

    PERIOD_RE = %r{
      (?:                             # 例: 2025年 8月 / 2025 年 8 月
        (20\d{2})\p{Space}*年\p{Space}*([01]?\d)\p{Space}*月
      )
      |
      (?:                             # 例: 2025.08 / 2025-08 / 2025/08
        (20\d{2})[\/\.\-]([01]?\d)
      )
    }ux

    SUMMARY_RE  = /\A([0-9０-９]+名|合計|小計|計)\z/
    SUMMARY_LABEL_RE = /\A[0-9０-９]+名\z/
    NON_NAME_RE = /(株式会社|有限会社|作成|支給控除|一覧表|度給与|合計|小計|計)/
    NAME_SPACE  = /\p{Space}/

    attr_reader :location

    def initialize(io, uploaded_by:, location:, expected_period: nil, period_mode: :strict)
      @io              = io
      @uploaded_by     = uploaded_by
      @location        = location.presence || "default"
      @expected_period = expected_period
      @period_mode     = period_mode.to_s
    end

    def call
      created = updated = skipped = 0
      warnings = []
      errors   = []

      spreadsheet = Roo::Spreadsheet.open(@io, extension: extname(@io))
      sheet = spreadsheet.sheet(0)

      file_period = detect_period(sheet)
      result = preflight_period_check(file_period, warnings, errors)
      return result if result

      @current_period = file_period || @expected_period || Date.current.beginning_of_month
      period_record = Period.find_or_create_by!(year: @current_period.year, month: @current_period.month)

      ActiveRecord::Base.transaction do
        cleanup_existing_data(period_record)

        batch = PayrollBatch.create!(
          period: period_record,
          location:,
          uploaded_by: @uploaded_by,
          original_filename: original_name,
          status: :processing,
          title: "#{period_record.label} #{location}"
        )

        header_row_idx = detect_header_row(sheet)
        headers = Array(sheet.row(header_row_idx)).map { |v| v.to_s.strip }

        pivot_mode = headers.any? { |h| h.include?("項目名") || h.include?("内訳") }
        if pivot_mode
          created, updated, skipped = import_pivot_sheet(sheet, header_row_idx, headers, period_record, batch, created, updated, skipped)
        else
          created, updated, skipped = import_vertical_sheet(sheet, header_row_idx, headers, period_record, batch, created, updated, skipped)
        end

        batch.update!(
          status: :completed,
          total_rows: created + updated + skipped,
          total_cells: created + updated
        )
      end

      Result.new(
        created:,
        updated:,
        skipped:,
        warnings:,
        errors:,
        period_from_file: file_period,
        period_mode: @period_mode
      )
    rescue StandardError => e
      Rails.logger.error("[PayrollImporter] #{e.class}: #{e.message}")
      Rails.logger.error(e.backtrace.take(10).join("\n"))
      Result.new(
        created:,
        updated:,
        skipped:,
        warnings:,
        errors: errors + [{ message: e.message, row: nil, hard: true }],
        period_from_file: file_period,
        period_mode: @period_mode
      )
    end

    private

    def original_name
      if @io.respond_to?(:original_filename)
        @io.original_filename.to_s
      else
        File.basename(@io.to_s)
      end
    end

    def preflight_period_check(file_period, warnings, errors)
      case @period_mode
      when "strict"
        if file_period.nil?
          errors << { message: "対象月をファイルから特定できません（厳密一致）", row: nil, hard: true }
          return Result.new(created: 0, updated: 0, skipped: 0, warnings:, errors:, period_from_file: nil, period_mode: @period_mode)
        end
        if @expected_period && file_period != @expected_period
          errors << { message: "UI指定月（#{fmt(@expected_period)}）とファイル内月（#{fmt(file_period)}）が一致しません（厳密一致）", row: nil, hard: true }
          return Result.new(created: 0, updated: 0, skipped: 0, warnings:, errors:, period_from_file: file_period, period_mode: @period_mode)
        end
      when "warn"
        if file_period.nil?
          warnings << { message: "対象月をファイルから特定できませんでした（警告モード）", row: nil }
        elsif @expected_period && file_period != @expected_period
          warnings << { message: "UI指定月（#{fmt(@expected_period)}）とファイル内月（#{fmt(file_period)}）が一致しません（警告）", row: nil }
        end
      end

      nil
    end

    def import_pivot_sheet(sheet, header_row_idx, headers, period, batch, created, updated, skipped)
      item_col = headers.index { |h| h.include?("項目名") || h.include?("内訳") } || 0

      code_row = header_row_idx > 1 ? Array(sheet.row(header_row_idx - 1)) : []
      next_row = (header_row_idx + 1) <= sheet.last_row ? Array(sheet.row(header_row_idx + 1)) : []
      column_labels = headers.each_with_index.map do |header, idx|
        primary = header.to_s.strip
        secondary = next_row[idx].to_s.strip
        code = code_row[idx].to_s.strip

        primary = secondary if primary.blank? && textual_value?(secondary)

        label_parts = []
        label_parts << code if code.present?
        label_parts << primary if primary.present?

        label = label_parts.join(" ").tr("\u3000", " ").squeeze(" ").strip
        label = primary if label.blank? && primary.present?
        label = code if label.blank? && code.present?

        [idx, label]
      end

      employee_columns = column_labels.select do |idx, label|
        next false if idx == item_col
        next false if label.blank?
        next false if label =~ NON_NAME_RE
        next false if label.match?(/\A\d+\z/) # numeric columns w/out names
        normalized_label = label.gsub(NAME_SPACE, "")
        next false if normalized_label.match?(SUMMARY_LABEL_RE)
        next false if normalized_label.include?("小計") || normalized_label.include?("合計")
        true
      end

      persist_column_order(period, employee_columns)

      monetary_section = false
      (header_row_idx + 1).upto(sheet.last_row) do |row_idx|
        row = Array(sheet.row(row_idx))
        raw_item_label = row[item_col].to_s.strip
        next if raw_item_label.blank?

        normalized = raw_item_label.gsub(NAME_SPACE, "")
        next if SUMMARY_RE.match?(normalized)

        item = find_or_create_item(raw_item_label, monetary_section)
        ensure_item_order(period, item, row_idx - header_row_idx - 1)

        employee_columns.each do |col_idx, label|
          employee = resolve_employee_from_label(label)
          next unless employee
          raw_value, amount = extract_cell_value(row[col_idx], monetary_section)

          if raw_value.blank? && amount.nil?
            skipped += 1
            next
          end

          created, updated = upsert_cell(period, batch, employee, item, raw_value, amount, created, updated)
        end

        monetary_section ||= raw_item_label.include?("基本給")
      end

      [created, updated, skipped]
    end

    def import_vertical_sheet(sheet, header_row_idx, headers, period, batch, created, updated, skipped)
      name_col = headers.index { |h| h.include?("氏名") || h.downcase.include?("name") } || 0
      item_headers = headers.each_with_index.filter_map do |header, idx|
        next if idx == name_col
        [idx, header.presence || "項目#{idx}"]
      end

      persist_column_order(period, item_headers.map { |_, label| [_, label] }, vertical: true)

      basic_index = item_headers.index { |_, label| label.include?("基本給") }

      (header_row_idx + 1).upto(sheet.last_row) do |row_idx|
        row = Array(sheet.row(row_idx))
        name = row[name_col].to_s
        normalized = name.gsub(NAME_SPACE, "")
        next if name.blank? || SUMMARY_RE.match?(normalized)

        employee = resolve_employee_from_label(name)
        next unless employee

        item_headers.each_with_index do |(idx, label), order_index|
          monetary_section = basic_index.present? && order_index >= basic_index
          raw_value, amount = extract_cell_value(row[idx], monetary_section)
          next if raw_value.blank? && amount.nil?

          item = find_or_create_item(label, monetary_section)
          ensure_item_order(period, item, order_index)

          created, updated = upsert_cell(period, batch, employee, item, raw_value, amount, created, updated)
        end
      end

      [created, updated, skipped]
    end

    def persist_column_order(period, columns, vertical: false)
      PayrollColumnOrder.where(period:, location:).delete_all

      columns.each_with_index do |(_, label), index|
        employee = vertical ? nil : resolve_employee_from_label(label)
        next unless !vertical && employee.present?

        PayrollColumnOrder.create!(
          period:,
          location:,
          employee:,
          column_index: index
        )
      end
    rescue ActiveRecord::RecordInvalid
      # vertical モードの場合は列順保存をスキップ（社員ヘッダがないため）
      vertical ? true : raise
    end

    def ensure_item_order(period, item, offset)
      order = ItemOrder.find_or_initialize_by(
        period:,
        location:,
        item:
      )
      order.row_index = offset
      order.save! if order.new_record? || order.changed?
    end

    def find_or_create_item(name, monetary_section)
      item = Item.find_or_initialize_by(name:, above_basic: monetary_section)
      desired_category = monetary_section ? "monetary" : "metric"
      item.category = desired_category if item.category != desired_category
      item.save! if item.new_record? || item.changed?
      item
    end

    def upsert_cell(period, batch, employee, item, raw, amount, created, updated)
      cell = PayrollCell.find_or_initialize_by(
        period:,
        location:,
        employee:,
        item:
      )
      previous_amount = cell.amount
      previous_raw = cell.raw

      cell.payroll_batch = batch
      cell.raw = raw
      cell.amount = amount

      if cell.new_record?
        cell.save!
        created += 1
      elsif previous_amount != amount || previous_raw != raw
        cell.save!
        updated += 1
      end

      [created, updated]
    end

    def resolve_employee_from_label(label)
      value = label.to_s.strip.tr("\n", " ")
      code = value[/\A(\d{3,})/, 1]
      cleaned = value.tr("\u3000", " ")
      sanitized = cleaned.gsub(/\A#{Regexp.escape(code)}\s*/u, "") if code.present?
      sanitized ||= cleaned
      sanitized = sanitized.squeeze(" ").strip
      sanitized = sanitized.gsub(/\s+\d+(?:\.\d+)?\z/, "")
      return nil if sanitized.blank?
      return nil if sanitized.match?(SUMMARY_LABEL_RE)
      return nil if sanitized.include?("小計") || sanitized.include?("合計")
      last_name, first_name = sanitized.split(/\s/, 2)

      employee = Employee.find_by(employee_code: code) if code.present?
      employee ||= Employee.find_by(full_name: sanitized)
      employee ||= Employee.all.find { |e| e.full_name.to_s.gsub(NAME_SPACE, "") == sanitized.gsub(NAME_SPACE, "") }

      if employee
        updates = {}
        updates[:employee_code] = code if code.present? && employee.employee_code != code
        updates[:full_name] = sanitized if sanitized.present? && employee.full_name != sanitized
        updates[:last_name] = last_name if last_name.present? && employee.last_name != last_name
        updates[:first_name] = first_name if first_name.present? && employee.first_name != first_name
        employee.update_columns(updates) if updates.any?
      else
        employee = Employee.create!(
          employee_code: code.presence || SecureRandom.hex(3),
          last_name: last_name,
          first_name: first_name,
          full_name: sanitized,
          current_status: "active"
        )
      end

      employee
    end

    def detect_header_row(sheet)
      1.upto([20, sheet.last_row].min) do |row_idx|
        row = Array(sheet.row(row_idx)).map { |v| v.to_s.strip }
        return row_idx if row.any? { |v| v.include?("氏名") || v.downcase.include?("name") || v.include?("項目名") || v.include?("内訳") }
      end
      1
    end

    def cleanup_existing_data(period)
      PayrollCell.where(period:, location:).delete_all
      ItemOrder.where(period:, location:).delete_all
      PayrollColumnOrder.where(period:, location:).delete_all
    end

    def detect_period(sheet)
      prefer = %r{(20\d{2})\p{Space}*年\p{Space}*([01]?\d)\p{Space}*月\p{Space}*度?}u

      1.upto([80, sheet.last_row].min) do |row_idx|
        text = normalized_row_text(sheet, row_idx)
        next if text.blank?
        next unless text.match?(/(給与|度給与|支給控除|一覧表)/)
        next if text.include?("作成")
        if (match = text.match(prefer))
          year, month = match[1].to_i, match[2].to_i
          return Date.new(year, month, 1) if year.positive? && (1..12).include?(month)
        end
      end

      1.upto([80, sheet.last_row].min) do |row_idx|
        text = normalized_row_text(sheet, row_idx)
        next if text.blank? || text.include?("作成")
        if (match = text.match(PERIOD_RE))
          year = (match[1] || match[3]).to_i
          month = (match[2] || match[4]).to_i
          return Date.new(year, month, 1) if year.positive? && (1..12).include?(month)
        end
      end

      nil
    end

    def normalized_row_text(sheet, row_idx)
      Array(sheet.row(row_idx)).compact.map(&:to_s).join(" ")
           .tr("０１２３４５６７８９", "0123456789")
           .gsub(/\u3000/, " ")
           .squeeze(" ")
           .strip
    end

    def textual_value?(value)
      return false if value.blank?

      normalized = value.tr("０１２３４５６７８９", "0123456789")
      normalized.match?(/[^\d\.\-:,\/\s]/)
    end

    def format_metric_numeric(value)
      return nil if value.nil?

      numeric = value.to_f
      return "" if numeric.zero?

      if numeric.positive? && numeric < 1
        total_minutes = (numeric * 24 * 60).round
        return time_string_from_minutes(total_minutes)
      end

      seconds = numeric.round
      return time_string_from_minutes((numeric / 60).round) if numeric >= 60 && (numeric % 60).zero?
      return time_string_from_minutes((seconds / 60)) if seconds >= 60 && (seconds % 60).zero?

      nil
    end

    def time_string_from_minutes(total_minutes)
      hours = (total_minutes / 60).to_i
      minutes = (total_minutes % 60).to_i
      format("%d:%02d", hours, minutes)
    end

    def extract_cell_value(value, monetary_section)
      return ["", nil] if value.nil?

      case value
      when Integer
        amount = value
        if monetary_section
          return ["", amount.zero? ? nil : amount]
        else
          formatted = format_metric_numeric(amount)
          return [formatted, nil] if formatted
          return [amount.zero? ? "" : amount.to_s, nil]
        end
      when Float
        if monetary_section
          amount = value.round
          return ["", amount.zero? ? nil : amount]
        else
          formatted = format_metric_numeric(value)
          return [formatted, nil] if formatted
          rounded = value.round(2)
          str = rounded.to_s.sub(/\.0+\z/, "")
          return [str == "0" ? "" : str, nil]
        end
      when defined?(BigDecimal) && value.is_a?(BigDecimal)
        if monetary_section
          amount = value.to_f.round
          return ["", amount.zero? ? nil : amount]
        else
          formatted = format_metric_numeric(value.to_f)
          return [formatted, nil] if formatted
          rounded = value.to_f.round(2)
          str = rounded.to_s.sub(/\.0+\z/, "")
          return [str == "0" ? "" : str, nil]
        end
      when Time, DateTime
        formatted = value.strftime("%H:%M")
        return [formatted == "00:00" ? "" : formatted, nil]
      when Date
        formatted = value.strftime("%Y-%m-%d")
        return [formatted, nil]
      end

      string = value.to_s.strip
      return ["", nil] if string.blank?

      if string.include?(":")
        parts = string.split(":")
        if parts.length == 2 && parts.all? { |p| p.match?(/\A\d+\z/) }
          hours = parts[0].to_i
          minutes = parts[1].to_i
          formatted = format("%d:%02d", hours, minutes)
          return [formatted == "0:00" ? "" : formatted, nil]
        end
      end

      if string.match?(/\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/)
        begin
          time = Time.parse(string)
          formatted = time.strftime("%H:%M")
          return [formatted == "00:00" ? "" : formatted, nil]
        rescue ArgumentError
          return [string, nil]
        end
      end

      normalized = string.tr("０１２３４５６７８９", "0123456789").gsub(/[, ]/, "")
      return [string, nil] if normalized.blank?

      if monetary_section
        begin
          amount = Float(normalized).round
          return ["", amount.zero? ? nil : amount]
        rescue ArgumentError
          return [string, nil]
        end
      else
        begin
          numeric = Float(normalized)
          if numeric.abs >= 3600 && (numeric % 60).zero?
            hours = (numeric / 3600).floor
            minutes = ((numeric % 3600) / 60).round
            if minutes == 60
              hours += 1
              minutes = 0
            end
            formatted = format("%d:%02d", hours, minutes)
            return [formatted == "0:00" ? "" : formatted, nil]
          end

          str = numeric.round(2).to_s.sub(/\.0+\z/, "")
          return [str == "0" ? "" : str, nil]
        rescue ArgumentError
          return [string, nil]
        end
      end
    end

    def extname(io)
      if io.respond_to?(:original_filename)
        File.extname(io.original_filename).delete(".")
      else
        File.extname(io.to_s).delete(".")
      end
    end

    def fmt(date)
      date&.strftime("%Y-%m")
    end

    def ensure_assignment_for(employee)
      effective_from = @current_period.beginning_of_month

      return if location.blank?

      assignment = employee.assignments.find_or_initialize_by(
        department: location,
        location: location,
        effective_from: effective_from
      )

      assignment.notes ||= "Imported from payroll data"

      assignment.save if assignment.new_record? || assignment.changed?
    rescue ActiveRecord::RecordInvalid
      # 無視（既存データとの競合など）
      true
    end
  end
end
