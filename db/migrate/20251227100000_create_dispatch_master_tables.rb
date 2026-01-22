class CreateDispatchMasterTables < ActiveRecord::Migration[7.1]
  def change
    # 荷主マスタ
    create_table :shippers do |t|
      t.references :tenant, null: false, foreign_key: true
      t.string :code, null: false
      t.string :name, null: false
      t.string :postal_code
      t.string :address
      t.string :phone
      t.string :fax
      t.string :contact_name
      t.string :billing_closing_day
      t.string :payment_terms
      t.text :notes
      t.timestamps
    end
    add_index :shippers, [:tenant_id, :code], unique: true

    # 届け先台帳
    create_table :destinations do |t|
      t.references :tenant, null: false, foreign_key: true
      t.references :shipper, foreign_key: true
      t.string :code, null: false
      t.string :name, null: false
      t.string :postal_code
      t.string :address
      t.string :phone
      t.decimal :latitude, precision: 10, scale: 7
      t.decimal :longitude, precision: 10, scale: 7
      t.text :notes
      t.timestamps
    end
    add_index :destinations, [:tenant_id, :code], unique: true

    # 傭車先マスタ
    create_table :subcontractor_companies do |t|
      t.references :tenant, null: false, foreign_key: true
      t.string :code, null: false
      t.string :name, null: false
      t.string :postal_code
      t.string :address
      t.string :phone
      t.string :fax
      t.string :contact_name
      t.string :rate_category
      t.text :notes
      t.timestamps
    end
    add_index :subcontractor_companies, [:tenant_id, :code], unique: true

    # 拠点間距離・時間
    create_table :route_distances do |t|
      t.references :tenant, null: false, foreign_key: true
      t.string :origin_code, null: false
      t.string :destination_code, null: false
      t.decimal :distance_km, precision: 8, scale: 2
      t.integer :duration_minutes
      t.text :notes
      t.timestamps
    end
    add_index :route_distances, [:tenant_id, :origin_code, :destination_code], unique: true, name: "idx_route_distances_unique"

    # タリフ（運賃表）
    create_table :tariffs do |t|
      t.references :tenant, null: false, foreign_key: true
      t.references :shipper, foreign_key: true
      t.string :code, null: false
      t.string :origin
      t.string :destination
      t.string :vehicle_class
      t.string :weight_category
      t.integer :unit_price
      t.date :effective_from
      t.date :effective_until
      t.text :notes
      t.timestamps
    end
    add_index :tariffs, [:tenant_id, :code], unique: true
  end
end
