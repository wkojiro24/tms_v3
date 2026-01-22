class AddFuelPriceToTenants < ActiveRecord::Migration[7.2]
  def change
    # ガソリン単価（円/L）- 半年ごとに更新
    add_column :tenants, :fuel_price, :decimal, precision: 5, scale: 1, default: 160.0
    # ガソリン単価更新日
    add_column :tenants, :fuel_price_updated_at, :date
  end
end
