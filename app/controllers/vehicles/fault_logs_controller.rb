module Vehicles
  class FaultLogsController < ApplicationController
    before_action :set_vehicle

    def create
      @fault_log = @vehicle.vehicle_fault_logs.build(fault_log_params)
      if @fault_log.save
        VehicleStatusManager.record(
          vehicle: @vehicle,
          status: VehicleStatusManager.status_for_fault(@fault_log),
          source: @fault_log,
          notes: @fault_log.title
        )
        redirect_to vehicle_path(@vehicle), notice: "故障記録を追加しました。"
      else
        redirect_to vehicle_path(@vehicle), alert: @fault_log.errors.full_messages.to_sentence
      end
    end

    private

    def set_vehicle
      @vehicle = Vehicle.find(params[:vehicle_id])
    end

    def fault_log_params
      params.require(:vehicle_fault_log).permit(
        :title,
        :occurred_on,
        :resolved_on,
        :status,
        :severity,
        :category,
        :description,
        :cause_primary,
        :estimated_cost,
        photos: []
      )
    end
  end
end
