class CreateEmployeeStatuses < ActiveRecord::Migration[7.2]
  def change
    create_table :employee_statuses do |t|
      t.references :employee, null: false, foreign_key: true
      t.string :status, null: false
      t.string :reason
      t.date :effective_from, null: false
      t.date :effective_to
      t.text :notes

      t.timestamps
    end
    add_index :employee_statuses, [:employee_id, :effective_from], name: "idx_employee_statuses_employee_from"
  end
end
