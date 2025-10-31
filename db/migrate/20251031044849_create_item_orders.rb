class CreateItemOrders < ActiveRecord::Migration[7.2]
  def change
    create_table :item_orders do |t|
      t.references :period, null: false, foreign_key: true
      t.string :location
      t.references :item, null: false, foreign_key: true
      t.integer :row_index, null: false

      t.timestamps
    end
    add_index :item_orders, [:period_id, :location, :item_id], unique: true, name: "idx_item_orders_period_location_item"
    add_index :item_orders, [:period_id, :location, :row_index], unique: true, name: "idx_item_orders_period_location_row"
  end
end
