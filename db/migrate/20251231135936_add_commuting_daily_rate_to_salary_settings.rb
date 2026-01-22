class AddCommutingDailyRateToSalarySettings < ActiveRecord::Migration[7.2]
  def change
    add_column :salary_settings, :commuting_daily_rate, :integer
  end
end
