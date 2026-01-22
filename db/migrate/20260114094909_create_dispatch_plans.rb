class CreateDispatchPlans < ActiveRecord::Migration[7.2]
  def change
    create_table :dispatch_plans do |t|
      t.references :tenant, null: false, foreign_key: true
      t.date :date, null: false
      t.text :notes
      t.integer :status, default: 0, null: false

      t.timestamps
    end

    add_index :dispatch_plans, [:tenant_id, :date], unique: true
  end
end
