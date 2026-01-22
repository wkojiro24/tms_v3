class AddDetailsToVehicleFaultLogs < ActiveRecord::Migration[7.2]
  def change
    add_column :vehicle_fault_logs, :cause_primary, :string
    add_column :vehicle_fault_logs, :estimated_cost, :decimal, precision: 12, scale: 2
  end
end
