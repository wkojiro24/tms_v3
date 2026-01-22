class AddSafetyBonusToSalarySettings < ActiveRecord::Migration[7.2]
  def change
    add_column :salary_settings, :safety_bonus, :integer
  end
end
