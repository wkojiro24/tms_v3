class CreateVehicles < ActiveRecord::Migration[7.2]
  def change
    create_table :vehicles do |t|
      t.references :tenant, null: false, foreign_key: true
      t.string :depot_name
      t.string :registration_number, null: false
      t.string :call_sign
      t.date :first_registration_on
      t.string :age_text
      t.string :model_code
      t.string :manufacturer_name
      t.string :chassis_number
      t.string :vehicle_category
      t.integer :max_load_kg
      t.integer :gross_weight_kg
      t.string :chassis_base
      t.string :pto
      t.string :shipper_name
      t.string :cargo_name
      t.string :specific_gravity
      t.date :tank_made_on
      t.string :tank_age_text
      t.string :hatch_pattern
      t.string :tank_material
      t.string :tank_manufacturer
      t.integer :tire_count
      t.string :body_type
      t.string :usage_category
      t.text :notes
      t.jsonb :metadata, null: false, default: {}

      t.timestamps
    end

    add_index :vehicles, [:tenant_id, :registration_number, :first_registration_on], unique: true, name: "idx_vehicles_unique_registration"
  end
end
