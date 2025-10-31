class CreatePayrollColumnOrders < ActiveRecord::Migration[7.2]
  def change
    create_table :payroll_column_orders do |t|
      t.references :period, null: false, foreign_key: true
      t.string :location
      t.references :employee, null: false, foreign_key: true
      t.integer :column_index, null: false

      t.timestamps
    end
    add_index :payroll_column_orders, [:period_id, :location, :employee_id], unique: true, name: "idx_payroll_column_orders_unique"
    add_index :payroll_column_orders, [:period_id, :location, :column_index], unique: true, name: "idx_payroll_column_orders_period_col"
  end
end
