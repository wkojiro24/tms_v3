class AddTransportOrderToDispatchAssignments < ActiveRecord::Migration[7.2]
  def change
    add_reference :dispatch_assignments, :transport_order, foreign_key: true
  end
end
