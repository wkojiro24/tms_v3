class CreateVehicleAliases < ActiveRecord::Migration[7.2]
  def change
    create_table :vehicle_aliases do |t|
      t.references :tenant, null: false, foreign_key: true
      t.string :pattern, null: false
      t.string :pattern_type, null: false, default: "exact"
      t.string :vehicle_id, null: false
      t.boolean :active, null: false, default: true
      t.jsonb :metadata, null: false, default: {}

      t.timestamps
    end

    add_index :vehicle_aliases, [:tenant_id, :vehicle_id]
    add_index :vehicle_aliases, [:tenant_id, :pattern], unique: true
  end
end
