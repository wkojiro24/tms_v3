class AddDetailsToMaintenanceEvents < ActiveRecord::Migration[7.1]
  def change
    add_column :maintenance_events, :status, :string, null: false, default: "scheduled"
    add_column :maintenance_events, :notes, :text
  end
end
