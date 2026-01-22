class CreateVehicleGroups < ActiveRecord::Migration[7.2]
  def change
    create_table :vehicle_groups do |t|
      t.references :tenant, foreign_key: true
      t.string :name, null: false
      t.string :group_type, default: "custom"
      t.jsonb :vehicle_codes, default: []
      t.jsonb :code_mappings, default: {}
      t.integer :position, default: 0

      t.timestamps
    end

    add_index :vehicle_groups, [:tenant_id, :name], unique: true
    add_index :vehicle_groups, [:tenant_id, :group_type]
  end
end
