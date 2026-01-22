class CreatePayrollCells < ActiveRecord::Migration[7.2]
  def change
    create_table :payroll_cells do |t|
      t.references :period, null: false, foreign_key: true
      t.references :employee, null: false, foreign_key: true
      t.references :item, null: false, foreign_key: true
      t.references :payroll_batch, null: false, foreign_key: true
      t.string :location
      t.string :raw
      t.decimal :amount, precision: 15, scale: 2

      t.timestamps
    end
    add_index :payroll_cells, [:period_id, :location, :employee_id, :item_id], unique: true, name: "idx_payroll_cells_unique"
  end
end
