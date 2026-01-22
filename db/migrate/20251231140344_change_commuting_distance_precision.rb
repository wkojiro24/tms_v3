class ChangeCommutingDistancePrecision < ActiveRecord::Migration[7.2]
  def change
    change_column :salary_settings, :commuting_distance, :decimal, precision: 6, scale: 2
  end
end
