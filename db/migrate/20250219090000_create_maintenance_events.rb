class CreateMaintenanceEvents < ActiveRecord::Migration[7.0]
  def change
    create_table :maintenance_events do |t|
      t.string :vehicle_number, null: false
      t.string :category, null: false
      t.datetime :start_at, null: false
      t.datetime :end_at

      t.timestamps
    end

    add_index :maintenance_events, :vehicle_number
    add_index :maintenance_events, :category
    add_index :maintenance_events, :start_at
  end
end
