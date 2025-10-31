class CreatePayrollBatches < ActiveRecord::Migration[7.2]
  def change
    create_table :payroll_batches do |t|
      t.references :period, null: false, foreign_key: true
      t.string :location
      t.string :title
      t.string :original_filename
      t.string :status, null: false, default: "pending"
      t.references :uploaded_by, null: false, foreign_key: { to_table: :users }
      t.integer :total_rows, default: 0
      t.integer :total_cells, default: 0
      t.text :notes

      t.timestamps
    end
    add_index :payroll_batches, [:period_id, :location], name: "idx_payroll_batches_period_location"
  end
end
