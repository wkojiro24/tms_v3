module Admin
  module PayrollsHelper
    def payroll_value(cell)
      return "" unless cell

      if cell.amount.present?
        return number_with_delimiter(format_numeric(cell.amount))
      end

      raw = cell.raw.to_s.strip
      return "" if raw.blank?
      return "" if raw == "0"

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

    private

    def numeric_string?(string)
      string.match?(/\A-?\d+(?:\.\d+)?\z/)
    end

    def format_numeric(value)
      number = value.to_f
      (number % 1).zero? ? number.to_i : number.round(2)
    end
  end
end
