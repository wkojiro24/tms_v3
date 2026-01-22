class CreateVehicleFaults < ActiveRecord::Migration[7.1]
  def change
    create_table :vehicle_faults do |t|
      t.references :tenant, null: false, foreign_key: true
      t.references :vehicle, null: false, foreign_key: true
      t.date :started_on, null: false
      t.date :resolved_on
      t.string :summary, null: false
      t.text :details

      t.timestamps
    end

    add_index :vehicle_faults, [:tenant_id, :vehicle_id, :started_on], name: "index_vehicle_faults_on_tenant_vehicle_started"
  end
end
