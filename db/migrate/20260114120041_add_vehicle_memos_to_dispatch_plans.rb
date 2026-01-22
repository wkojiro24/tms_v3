class AddVehicleMemosToDispatchPlans < ActiveRecord::Migration[7.2]
  def change
    add_column :dispatch_plans, :vehicle_memos, :text
  end
end
