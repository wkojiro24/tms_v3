class FixSalaryMonthlyPrecision < ActiveRecord::Migration[7.2]
  def change
    change_column :salary_monthlies, :paid_leave_hours, :decimal, precision: 10, scale: 2
  end
end
