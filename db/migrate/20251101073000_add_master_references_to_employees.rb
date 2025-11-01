class AddMasterReferencesToEmployees < ActiveRecord::Migration[7.2]
  def change
    add_reference :employees, :department, foreign_key: true
    add_reference :employees, :job_category, foreign_key: true
    add_reference :employees, :job_position, foreign_key: true
    add_reference :employees, :grade_level, foreign_key: true

    add_index :employees, [:tenant_id, :department_id]
    add_index :employees, [:tenant_id, :job_category_id]
    add_index :employees, [:tenant_id, :job_position_id]
    add_index :employees, [:tenant_id, :grade_level_id]
  end
end
