class CreateVehicleFinancialMetrics < ActiveRecord::Migration[7.2]
  def change
    create_table :vehicle_financial_metrics do |t|
      t.references :tenant, null: false, foreign_key: true
      t.references :vehicle, null: true, foreign_key: true
      t.string :vehicle_code, null: false
      t.date :month, null: false
      t.string :metric_key, null: false
      t.string :metric_label, null: false
      t.decimal :value_numeric, precision: 18, scale: 2
      t.string :value_text
      t.string :unit
      t.string :source_file
      t.jsonb :metadata, null: false, default: {}

      t.timestamps
    end

    add_index :vehicle_financial_metrics, [:tenant_id, :month]
    add_index :vehicle_financial_metrics, [:tenant_id, :vehicle_code, :month, :metric_key], name: "index_vehicle_financial_metrics_dedup"
  end
end
