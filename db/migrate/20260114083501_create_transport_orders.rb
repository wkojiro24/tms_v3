class CreateTransportOrders < ActiveRecord::Migration[7.2]
  def change
    create_table :transport_orders do |t|
      t.references :tenant, null: false, foreign_key: true
      t.string :order_no
      t.date :order_date, null: false
      t.references :vehicle, foreign_key: true
      t.references :employee, foreign_key: true
      t.references :department, foreign_key: true
      t.references :shipper, foreign_key: true
      t.date :loading_date
      t.time :loading_time
      t.date :departure_date
      t.time :departure_time
      t.date :arrival_date
      t.time :arrival_time
      t.references :origin_location, foreign_key: { to_table: :destinations }
      t.references :destination_location, foreign_key: { to_table: :destinations }
      t.decimal :quantity, precision: 10, scale: 2
      t.string :unit
      t.decimal :weight, precision: 10, scale: 2
      t.decimal :distance_km, precision: 10, scale: 2
      t.decimal :driving_km, precision: 10, scale: 2
      t.decimal :billing_unit_price, precision: 10, scale: 2
      t.integer :billing_base_amount, default: 0
      t.integer :billing_surcharge, default: 0
      t.integer :billing_toll, default: 0
      t.integer :billing_other, default: 0
      t.integer :billing_tax, default: 0
      t.integer :billing_total, default: 0
      t.date :billing_date
      t.date :billing_closing_date
      t.decimal :payment_unit_price, precision: 10, scale: 2
      t.integer :payment_base_amount, default: 0
      t.integer :payment_toll, default: 0
      t.integer :payment_tax, default: 0
      t.integer :vehicle_amount, default: 0
      t.integer :driver_amount, default: 0
      t.text :remarks
      t.integer :status, default: 0

      t.timestamps
    end

    add_index :transport_orders, [:tenant_id, :order_no], unique: true
    add_index :transport_orders, [:tenant_id, :order_date]
    add_index :transport_orders, [:tenant_id, :billing_date]
  end
end
