module Admin
  module PayrollsHelper
    def payroll_value(cell)
      return "" unless cell

      if cell.amount.present?
        return number_with_delimiter(format_numeric(cell.amount))
      end

      raw_original = cell.raw.to_s
      raw = normalize_raw_value(raw_original)
      return "" if raw.blank?

      if monetary_cell?(cell)
        monetary_value = normalize_monetary_value(raw, raw_original)
        return monetary_value unless monetary_value.nil?
      end

      if numeric_string?(raw)
        formatted = format_numeric(raw.to_f)
        return "" if formatted.zero?
        number_with_delimiter(formatted)
      else
        raw
      end
    end

    def employee_header_name(employee)
      name = employee.full_name.presence || [employee.last_name, employee.first_name].compact.join(" ")
      name = name.to_s.gsub(/\s+\d+(?:\.\d+)?\z/, "").strip
      name.presence || employee.employee_code
    end

    # 小計計算用の数値取得
    def payroll_numeric_value(cell)
      return 0 unless cell

      if cell.amount.present?
        return cell.amount.to_f
      end

      raw_original = cell.raw.to_s
      raw = normalize_raw_value(raw_original)
      return 0 if raw.blank?

      if monetary_cell?(cell)
        # 時間形式（例: "53:20"）を秒数に変換
        if raw.include?(":")
          amount = coerce_time_to_amount_numeric(raw_original)
          return amount if amount && amount > 0
        end

        numeric_text = raw.tr("０１２３４５６７８９", "0123456789").gsub(/[, ]/, "")
        return Float(numeric_text) rescue 0
      end

      0
    end

    # 時間値を取得（変動給の根拠表示用）
    def payroll_hours_value(cell)
      return 0 unless cell

      raw = cell.raw.to_s
      return 0 if raw.blank?

      if raw.include?(":")
        parts = raw.split(":")
        return parts[0].to_f + parts[1].to_f / 60.0
      end

      raw.to_f
    end

    # 時間形式を数値（秒数）に変換（小計計算用）
    def coerce_time_to_amount_numeric(original)
      text = original.to_s
      return nil unless text.include?(":")

      parts = text.split(":")
      return nil unless parts.length >= 2

      left = parts.first
      return nil unless left.match?(/\A\d+\z/)

      middle = parts[1]
      return nil if middle.match?(/19\d{2}|20\d{2}/)

      hours = parts[0].to_i
      minutes = parts[1].to_i
      seconds = parts.length > 2 ? parts[2].to_i : 0

      total_seconds = hours * 3600 + minutes * 60 + seconds
      return nil if total_seconds.zero?

      total_seconds
    end

    private

    def normalize_raw_value(value)
      text = value.to_s.gsub(/[\u00A0\u200B\u200C\u200D]/, "").tr("\u3000", " ").strip
      return "" if text.blank? || text == "0"

      if text =~ /(18|19)\d{2}-\d{2}-\d{2}/
        normalized_time_from_excel(text) || text
      elsif text.match?(/\A\d{1,2}:\d{2}:\d{2}\z/)
        hh, mm, _ss = text.split(":")
        format("%d:%02d", hh.to_i, mm.to_i)
      else
        text.squeeze(" ")
      end
    end

    def normalize_monetary_value(raw, original)
      if raw.include?(":")
        coerced = coerce_time_to_amount(original)
        return coerced unless coerced.nil?
        return ""
      end

      numeric_text = raw.tr("０１２３４５６７８９", "0123456789").gsub(/[, ]/, "")
      return nil if numeric_text.blank?

      numeric_value = Float(numeric_text)
      return nil if numeric_value.zero?

      number_with_delimiter(format_numeric(numeric_value))
    rescue ArgumentError
      nil
    end

    def monetary_cell?(cell)
      return false unless cell.respond_to?(:item)

      item = cell.item
      return false unless item

      return true if item.monetary_section?
      return true if item.base_salary?  # 基本給グループの項目も小計に含める

      name = item.name.to_s
      name.include?("基本給")
    end

    def coerce_time_to_amount(original)
      text = original.to_s
      return nil unless text.include?(":")

      parts = text.split(":")
      return nil unless parts.length >= 2

      left = parts.first
      return nil unless left.match?(/\A\d+\z/)

      middle = parts[1]
      return nil if middle.match?(/19\d{2}|20\d{2}/)

      hours = parts[0].to_i
      minutes = parts[1].to_i
      seconds = parts.length > 2 ? parts[2].to_i : 0

      total_seconds = hours * 3600 + minutes * 60 + seconds
      return nil if total_seconds.zero?

      number_with_delimiter(total_seconds)
    end

    def normalized_time_from_excel(text)
      time = Time.zone.parse(text) rescue nil
      return unless time && time.respond_to?(:hour) && time.respond_to?(:min)

      seconds_zero = if time.respond_to?(:sec)
                       time.sec.zero?
      elsif time.respond_to?(:second)
                       time.second.zero?
      else
                       true
      end

      return "" if time.hour.zero? && time.min.zero? && seconds_zero

      if time.respond_to?(:year) && time.year <= 1901
        format("%d:%02d", time.hour, time.min)
      end
    end

    def numeric_string?(string)
      string.match?(/\A-?\d+(?:\.\d+)?\z/)
    end

    def format_numeric(value)
      number = value.to_f
      (number % 1).zero? ? number.to_i : number.round(2)
    end
  end
end
