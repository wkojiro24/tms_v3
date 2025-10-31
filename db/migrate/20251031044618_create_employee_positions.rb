class CreateEmployeePositions < ActiveRecord::Migration[7.2]
  def change
    create_table :employee_positions do |t|
      t.references :employee, null: false, foreign_key: true
      t.string :title
      t.string :grade
      t.date :effective_from, null: false
      t.date :effective_to
      t.text :notes

      t.timestamps
    end
    add_index :employee_positions, [:employee_id, :effective_from], name: "idx_employee_positions_employee_from"
  end
end
