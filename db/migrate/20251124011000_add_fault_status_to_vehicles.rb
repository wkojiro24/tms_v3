class AddFaultStatusToVehicles < ActiveRecord::Migration[7.1]
  def change
    add_column :vehicles, :fault_status, :integer, null: false, default: 0
  end
end
