class CreateDispatchAssignments < ActiveRecord::Migration[7.2]
  def change
    create_table :dispatch_assignments do |t|
      t.references :tenant, null: false, foreign_key: true
      t.references :dispatch_plan, null: false, foreign_key: true
      t.references :vehicle, foreign_key: true
      t.references :employee, foreign_key: true
      t.references :shipper, foreign_key: true
      t.references :origin_location, foreign_key: { to_table: :destinations }
      t.references :destination_location, foreign_key: { to_table: :destinations }

      # 順序（1回目、2回目、3回目...）
      t.integer :sequence, default: 1, null: false

      # 時間関連
      t.time :scheduled_departure   # 出勤予定時間
      t.time :scheduled_arrival     # 指定時間（納品時間）
      t.time :estimated_return      # 帰庫予定時間

      # 品目・荷主情報
      t.string :product_name        # 品名（塩酸、苛性ソーダ等）
      t.string :cargo_type          # 積載物種類

      # 指示事項
      t.string :instruction         # 積発、宵積み等
      t.text :route_instruction     # 高速道路ほか指示事項
      t.text :remarks               # その他備考

      # ステータス
      t.integer :status, default: 0, null: false
      t.boolean :delivery_slip_confirmed, default: false  # 納品書確認

      t.timestamps
    end

    add_index :dispatch_assignments, [:dispatch_plan_id, :vehicle_id, :sequence],
              name: 'idx_dispatch_assignments_plan_vehicle_seq'
  end
end
