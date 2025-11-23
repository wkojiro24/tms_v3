class CreateVehicleStatuses < ActiveRecord::Migration[7.2]
  def change
    create_table :vehicle_statuses do |t|
      t.references :tenant, null: false, foreign_key: true
      t.references :vehicle, null: false, foreign_key: true
      t.string :status, null: false
      t.string :source_type
      t.bigint :source_id
      t.date :effective_on
      t.string :notes
      t.jsonb :metadata, default: {}, null: false

      t.timestamps
    end

    add_index :vehicle_statuses, [:source_type, :source_id]
  end
end
