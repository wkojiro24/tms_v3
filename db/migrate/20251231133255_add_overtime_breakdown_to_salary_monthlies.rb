class AddOvertimeBreakdownToSalaryMonthlies < ActiveRecord::Migration[7.2]
  def change
    add_column :salary_monthlies, :weekday_overtime_pay, :integer
    add_column :salary_monthlies, :statutory_holiday_pay, :integer
    add_column :salary_monthlies, :non_statutory_holiday_pay, :integer
    add_column :salary_monthlies, :substitute_holiday_pay, :integer
    add_column :salary_monthlies, :premium_overtime_pay, :integer
    add_column :salary_monthlies, :late_night_pay, :integer
  end
end
