class AddSubstituteHolidayPayToSalarySimulations < ActiveRecord::Migration[7.2]
  def change
    add_column :salary_simulations, :calc_substitute_holiday_pay, :integer, default: 0
  end
end
