module Vehicles
  class MaintenanceEventsController < ApplicationController
    before_action :set_vehicle
    before_action :set_event, only: [:edit, :update, :destroy]

    def new
      @maintenance_event = @vehicle.maintenance_events.build(
        start_at: Time.zone.today,
        status: "scheduled"
      )
      render_form
    end

    def edit
      render_form
    end

    def create
      @maintenance_event = @vehicle.maintenance_events.build(event_params.merge(vehicle_number: @vehicle.registration_number))
      if @maintenance_event.save
        redirect_to vehicle_path(@vehicle, anchor: "maintenance"), notice: "メンテナンス記録を登録しました。"
      else
        render_form(status: :unprocessable_entity)
      end
    end

    def update
      if @maintenance_event.update(event_params.merge(vehicle_number: @vehicle.registration_number))
        redirect_to vehicle_path(@vehicle, anchor: "maintenance"), notice: "メンテナンス記録を更新しました。"
      else
        render_form(status: :unprocessable_entity)
      end
    end

    def destroy
      @maintenance_event.destroy!
      redirect_to vehicle_path(@vehicle, anchor: "maintenance"), notice: "メンテナンス記録を削除しました。"
    end

    private

    def render_form(status: :ok)
      @maintenance_categories = MaintenanceCategory.order(:key)
      render template: "vehicles/maintenance_events/form", status: status
    end

    def set_vehicle
      @vehicle = Vehicle.find(params[:vehicle_id])
    end

    def set_event
      @maintenance_event = @vehicle.maintenance_events.find(params[:id])
    end

    def event_params
      params.require(:maintenance_event).permit(:category, :start_at, :end_at, :status, :notes)
    end
  end
end
