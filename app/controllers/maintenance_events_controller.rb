class MaintenanceEventsController < ApplicationController
  protect_from_forgery with: :null_session, unless: -> { request.format.html? }

  def create
    event = MaintenanceEvent.new(event_params)
    if event.save
      render json: { id: event.id }, status: :created
    else
      render json: { errors: event.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    event = MaintenanceEvent.find(params[:id])
    if event.update(event_params)
      head :no_content
    else
      render json: { errors: event.errors.full_messages }, status: :unprocessable_entity
    end
  rescue ActiveRecord::RecordNotFound
    head :not_found
  end

  def destroy
    event = MaintenanceEvent.find(params[:id])
    event.destroy!
    head :no_content
  rescue ActiveRecord::RecordNotFound
    head :not_found
  end

  private

  def event_params
    params.require(:maintenance_event).permit(:vehicle_number, :category, :start_at, :end_at)
  end
end
