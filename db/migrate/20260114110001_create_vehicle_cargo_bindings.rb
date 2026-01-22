class CreateVehicleCargoBindings < ActiveRecord::Migration[7.2]
  def change
    create_table :vehicle_cargo_bindings do |t|
      t.references :tenant, null: false, foreign_key: true
      t.references :vehicle, null: false, foreign_key: true
      t.string :cargo_name, null: false
      t.string :cargo_category
      t.references :shipper, foreign_key: true
      t.references :default_origin, foreign_key: { to_table: :destinations }
      t.references :default_destination, foreign_key: { to_table: :destinations }
      t.boolean :is_default, default: true, null: false
      t.integer :priority, default: 0, null: false
      t.text :notes
      t.timestamps
    end

    add_index :vehicle_cargo_bindings, [:tenant_id, :vehicle_id]
    add_index :vehicle_cargo_bindings, [:tenant_id, :cargo_category]
  end
end
