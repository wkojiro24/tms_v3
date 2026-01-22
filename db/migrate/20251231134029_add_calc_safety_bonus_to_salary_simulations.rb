class AddCalcSafetyBonusToSalarySimulations < ActiveRecord::Migration[7.2]
  def change
    add_column :salary_simulations, :calc_safety_bonus, :integer
  end
end
