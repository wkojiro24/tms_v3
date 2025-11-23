class VehicleMaintenanceOverview
  attr_reader :vehicle

  def initialize(vehicle:)
    @vehicle = vehicle
  end

  def repair_requests(limit: 5)
    scope = repair_request_scope
    return scope if limit.nil?

    scope.limit(limit)
  end

  def fault_logs(limit: 5)
    vehicle.vehicle_fault_logs.order(occurred_on: :desc, created_at: :desc).limit(limit)
  end

  def inspection_records(limit: nil)
    scope = vehicle.vehicle_inspection_records.order(scheduled_on: :desc, created_at: :desc)
    limit ? scope.limit(limit) : scope
  end

  def inspection_schedule_events
    VehicleInspectionSchedule.new(vehicle: vehicle).events
  end

  private

  def repair_request_scope
    return WorkflowRequest.none if vehicle.blank?
    return @repair_request_scope if defined?(@repair_request_scope)

    identifiers = identifier_candidates
    if identifiers.blank?
      @repair_request_scope = WorkflowRequest.none
      return @repair_request_scope
    end

    base_scope = WorkflowRequest
                 .includes(:workflow_category)
                 .joins(:workflow_category)
                 .where(workflow_categories: { code: "vehicle_repair" })

    conditions = []
    values = {}
    identifiers.each_with_index do |identifier, index|
      next if identifier.blank?

      like_value = "%#{ActiveRecord::Base.sanitize_sql_like(identifier)}%"

      conditions << <<~SQL.squish
        (workflow_requests.vehicle_identifier = :exact_#{index}
          OR workflow_requests.vehicle_identifier ILIKE :like_#{index}
          OR workflow_requests.metadata ->> 'repair_vehicle' = :exact_#{index}
          OR workflow_requests.metadata ->> 'repair_vehicle' ILIKE :like_#{index})
      SQL
      values[:"exact_#{index}"] = identifier
      values[:"like_#{index}"] = like_value
    end

    if conditions.blank?
      @repair_request_scope = WorkflowRequest.none
    else
      @repair_request_scope = base_scope
                              .where([conditions.join(" OR "), values])
                              .distinct
                              .order(submitted_at: :desc, created_at: :desc)
    end

    @repair_request_scope
  end

  def identifier_candidates
    [
      vehicle.registration_number,
      vehicle.call_sign,
      vehicle.display_name
    ].compact_blank.uniq
  end
end
