class CreateEmployees < ActiveRecord::Migration[7.2]
  def change
    create_table :employees do |t|
      t.string :employee_code, limit: 50, null: false
      t.string :last_name
      t.string :first_name
      t.string :last_name_kana
      t.string :first_name_kana
      t.string :full_name
      t.date :date_of_birth
      t.date :hire_date
      t.string :email
      t.string :phone
      t.string :current_status, null: false, default: "active"
      t.text :notes

      t.timestamps
    end
    add_index :employees, :employee_code, unique: true
  end
end
