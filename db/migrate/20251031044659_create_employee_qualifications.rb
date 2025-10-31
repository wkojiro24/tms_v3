class CreateEmployeeQualifications < ActiveRecord::Migration[7.2]
  def change
    create_table :employee_qualifications do |t|
      t.references :employee, null: false, foreign_key: true
      t.string :name, null: false
      t.string :issuer
      t.date :acquired_on
      t.date :expires_on
      t.string :license_number
      t.text :notes

      t.timestamps
    end
    add_index :employee_qualifications, [:employee_id, :name], name: "idx_employee_qualifications_employee_name"
  end
end
