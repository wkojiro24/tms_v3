class CreateExternalEconomicData < ActiveRecord::Migration[7.2]
  def change
    create_table :external_economic_data do |t|
      t.string :data_type, null: false  # minimum_wage, diesel_price, truck_price, cpi
      t.integer :year, null: false
      t.integer :month  # null = 年間データ
      t.decimal :value, precision: 15, scale: 2
      t.string :region  # 地域（最低賃金は都道府県別）
      t.string :source
      t.text :notes

      t.timestamps
    end

    add_index :external_economic_data, [:data_type, :year, :month]
    add_index :external_economic_data, [:data_type, :year, :region]
  end
end
