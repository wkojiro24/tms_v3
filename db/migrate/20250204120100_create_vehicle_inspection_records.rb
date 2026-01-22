class CreateVehicleInspectionRecords < ActiveRecord::Migration[7.2]
  def change
    create_table :vehicle_inspection_records do |t|
      t.references :tenant, null: false, foreign_key: true
      t.references :vehicle, null: false, foreign_key: true
      t.string :inspection_type, null: false
      t.date :scheduled_on
      t.date :completed_on
      t.string :status, null: false, default: "scheduled"
      t.string :inspector_name
      t.text :notes

      t.timestamps
    end

    add_index :vehicle_inspection_records, [:tenant_id, :vehicle_id, :scheduled_on], name: "index_inspections_on_tenant_vehicle_scheduled"
  end
end
