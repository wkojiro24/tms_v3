class AddDefaultEmployeeToVehicles < ActiveRecord::Migration[7.2]
  def change
    add_column :vehicles, :default_employee_id, :bigint
  end
end
