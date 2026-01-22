class VehicleStatusManager
  def self.record(vehicle:, status:, source:, notes: nil)
    return if status.blank?

    vehicle.vehicle_statuses.create!(
      status: status,
      source: source,
      effective_on: Date.current,
      notes: notes
    )
  end

  def self.status_for_fault(log)
    case log.status
    when "repair_ordered"
      "maintenance"
    when "estimating", "on_hold"
      "attention"
    else
      "active"
    end
  end

  def self.status_for_inspection(record)
    case record.status
    when "scheduled", "overdue"
      "inspection"
    when "completed"
      "active"
    else
      "active"
    end
  end
end
