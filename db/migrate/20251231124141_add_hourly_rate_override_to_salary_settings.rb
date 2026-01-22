class AddHourlyRateOverrideToSalarySettings < ActiveRecord::Migration[7.2]
  def change
    add_column :salary_settings, :hourly_rate_override, :integer
  end
end
