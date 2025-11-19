class CreateVehicleFaultLogs < ActiveRecord::Migration[7.2]
  def change
    create_table :vehicle_fault_logs do |t|
      t.references :tenant, null: false, foreign_key: true
      t.references :vehicle, null: false, foreign_key: true
      t.string :title, null: false
      t.date :occurred_on
      t.date :resolved_on
      t.string :status, null: false, default: "open"
      t.string :severity, null: false, default: "medium"
      t.string :category
      t.text :description

      t.timestamps
    end

    add_index :vehicle_fault_logs, [:tenant_id, :vehicle_id, :occurred_on], name: "index_fault_logs_on_tenant_vehicle_date"
  end
end
