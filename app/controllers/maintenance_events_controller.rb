class MaintenanceEventsController < ApplicationController
  before_action :set_event, only: [:update, :destroy]

  def create
    vehicle = Vehicle.find(params.require(:vehicle_id))
    scheduled_on = parse_date(params[:scheduled_on])

    record = vehicle.vehicle_inspection_records.create!(
      inspection_type: params[:inspection_type].presence || "点検",
      inspection_scope: params[:inspection_scope].presence || "その他",
      status: params[:status].presence || "scheduled",
      scheduled_on: scheduled_on,
      notes: params[:notes]
    )
    VehicleStatusManager.record(
      vehicle: vehicle,
      status: VehicleStatusManager.status_for_inspection(record),
      source: record,
      notes: record.inspection_type
    )

    render json: event_payload(record), status: :created
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.record.errors.full_messages.to_sentence }, status: :unprocessable_entity
  end

  def update
    scheduled_on = parse_date(params[:scheduled_on])
    attrs = { scheduled_on: scheduled_on }
    attrs[:vehicle_id] = params[:vehicle_id] if params[:vehicle_id].present?
    if @event.update(attrs)
      render json: event_payload(@event)
    else
      render json: { error: @event.errors.full_messages.to_sentence }, status: :unprocessable_entity
    end
  end

  def destroy
    @event.destroy!
    head :no_content
  end

  private

  def set_event
    @event = VehicleInspectionRecord.find(params[:id])
  end

  def parse_date(value)
    Date.parse(value)
  rescue ArgumentError, TypeError
    nil
  end

  def event_payload(record)
    {
      id: record.id,
      vehicle_id: record.vehicle_id,
      inspection_type: record.inspection_type,
      inspection_scope: record.inspection_scope,
      status: record.status,
      scheduled_on: record.scheduled_on
    }
  end
end
