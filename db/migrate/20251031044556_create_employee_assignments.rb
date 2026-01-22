class CreateEmployeeAssignments < ActiveRecord::Migration[7.2]
  def change
    create_table :employee_assignments do |t|
      t.references :employee, null: false, foreign_key: true
      t.string :department
      t.string :location
      t.string :employment_type
      t.string :position_title
      t.date :effective_from, null: false
      t.date :effective_to
      t.text :notes

      t.timestamps
    end
    add_index :employee_assignments, [:employee_id, :effective_from], name: "idx_employee_assignments_employee_from"
  end
end
