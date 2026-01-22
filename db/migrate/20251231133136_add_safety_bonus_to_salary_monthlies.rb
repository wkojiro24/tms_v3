class AddSafetyBonusToSalaryMonthlies < ActiveRecord::Migration[7.2]
  def change
    add_column :salary_monthlies, :safety_bonus, :integer
  end
end
