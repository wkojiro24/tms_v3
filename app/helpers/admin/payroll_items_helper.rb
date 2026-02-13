# frozen_string_literal: true

module Admin
  module PayrollItemsHelper
    def group_row_class(payroll_group)
      return "" if payroll_group.blank?

      "group-#{payroll_group}"
    end
  end
end
