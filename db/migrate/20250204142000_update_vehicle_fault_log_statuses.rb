class UpdateVehicleFaultLogStatuses < ActiveRecord::Migration[7.2]
  def up
    change_column_default :vehicle_fault_logs, :status, "on_hold"
    execute <<~SQL
      UPDATE vehicle_fault_logs
      SET status = CASE status
        WHEN 'open' THEN 'on_hold'
        WHEN 'in_progress' THEN 'repair_ordered'
        WHEN 'resolved' THEN 'other'
        ELSE status
      END
    SQL
  end

  def down
    execute <<~SQL
      UPDATE vehicle_fault_logs
      SET status = CASE status
        WHEN 'on_hold' THEN 'open'
        WHEN 'repair_ordered' THEN 'in_progress'
        WHEN 'other' THEN 'resolved'
        ELSE status
      END
    SQL
    change_column_default :vehicle_fault_logs, :status, "open"
  end
end
