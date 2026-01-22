class AddVehicleGroupToVehicles < ActiveRecord::Migration[7.2]
  def change
    add_column :vehicles, :vehicle_group, :string
  end
end
