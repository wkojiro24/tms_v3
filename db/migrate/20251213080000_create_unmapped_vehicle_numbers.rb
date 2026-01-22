class CreateUnmappedVehicleNumbers < ActiveRecord::Migration[7.2]
  def change
    create_table :unmapped_vehicle_numbers do |t|
      t.references :tenant, null: false, foreign_key: true
      t.string :raw_number, null: false
      t.string :cleaned_number
      t.integer :occurrence_count, default: 1, null: false
      t.datetime :first_seen_at, null: false
      t.datetime :last_seen_at, null: false
      t.boolean :resolved, default: false, null: false
      t.string :resolved_to
      t.text :notes

      t.timestamps
    end

    add_index :unmapped_vehicle_numbers,
              [:tenant_id, :raw_number],
              unique: true,
              name: "idx_unmapped_vehicle_numbers_unique"
  end
end
