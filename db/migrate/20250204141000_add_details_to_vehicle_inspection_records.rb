class AddDetailsToVehicleInspectionRecords < ActiveRecord::Migration[7.2]
  def change
    add_column :vehicle_inspection_records, :inspection_scope, :string
    add_column :vehicle_inspection_records, :vendor_name, :string
    add_column :vehicle_inspection_records, :estimated_cost, :decimal, precision: 12, scale: 2
  end
end
