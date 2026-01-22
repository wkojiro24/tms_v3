class AddAlertFlagToDispatchAssignments < ActiveRecord::Migration[7.2]
  def change
    add_column :dispatch_assignments, :alert_flag, :boolean, default: false, null: false
  end
end
