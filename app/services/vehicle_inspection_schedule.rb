class VehicleInspectionSchedule
  attr_reader :vehicle, :today

  INSPECTION_WARNING_THRESHOLD = 60
  INSPECTION_ALERT_THRESHOLD = 30
  TANK_REINSPECTION_MONTHS = 60

  def initialize(vehicle:, today: Date.current)
    @vehicle = vehicle
    @today = today
  end

  def events
    @events ||= [shaken_event, periodic_event, tank_event].compact
  end

  private

  def shaken_event
    schedule = build_schedule(base_date: vehicle.first_registration_on, interval_months: shaken_interval_months)
    return if schedule.blank?

    schedule.merge(
      label: "車検",
      interval_label: "#{shaken_interval_months}ヶ月ごと",
      urgency: urgency(schedule[:days_remaining])
    )
  end

  def periodic_event
    schedule = build_schedule(base_date: vehicle.first_registration_on, interval_months: periodic_interval_months)
    return if schedule.blank?

    schedule.merge(
      label: "定期点検 (12ヶ月)",
      interval_label: "12ヶ月ごと",
      urgency: urgency(schedule[:days_remaining])
    )
  end

  def tank_event
    return if vehicle.tank_made_on.blank?

    schedule = build_schedule(base_date: vehicle.tank_made_on, interval_months: TANK_REINSPECTION_MONTHS)
    return if schedule.blank?

    schedule.merge(
      label: "タンク再検",
      interval_label: "5年ごと",
      urgency: urgency(schedule[:days_remaining])
    )
  end

  def build_schedule(base_date:, interval_months:)
    return if base_date.blank? || interval_months.to_i <= 0

    next_due_on = base_date
    previous_due_on = nil
    while next_due_on <= today
      previous_due_on = next_due_on
      next_due_on = next_due_on.advance(months: interval_months)
    end

    {
      next_due_on: next_due_on,
      previous_due_on: previous_due_on,
      interval_months: interval_months,
      days_remaining: (next_due_on - today).to_i
    }
  end

  def shaken_interval_months
    gross_weight = vehicle.gross_weight_kg.to_i
    return 12 if gross_weight >= 8000 || gross_weight.zero?

    24
  end

  def periodic_interval_months
    12
  end

  def urgency(days_remaining)
    return "danger" if days_remaining <= INSPECTION_ALERT_THRESHOLD
    return "warning" if days_remaining <= INSPECTION_WARNING_THRESHOLD

    "secondary"
  end
end
