class AddDetailsToMaintenanceEventsExtended < ActiveRecord::Migration[7.1]
  def change
    add_column :maintenance_events, :repair_location, :string
    add_column :maintenance_events, :vendor_name, :string
    add_column :maintenance_events, :estimated_cost, :decimal, precision: 12, scale: 2
  end
end
