class AddRegularOvertimePayToSalaryMonthlies < ActiveRecord::Migration[7.2]
  def change
    add_column :salary_monthlies, :regular_overtime_pay, :integer
  end
end
