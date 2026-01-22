module Vehicles
  class InspectionRecordsController < ApplicationController
    before_action :set_vehicle

    def create
      @inspection_record = @vehicle.vehicle_inspection_records.build(inspection_params)
      if @inspection_record.save
        VehicleStatusManager.record(
          vehicle: @vehicle,
          status: VehicleStatusManager.status_for_inspection(@inspection_record),
          source: @inspection_record,
          notes: @inspection_record.inspection_type
        )
        redirect_to vehicle_path(@vehicle), notice: "点検記録を追加しました。"
      else
        redirect_to vehicle_path(@vehicle), alert: @inspection_record.errors.full_messages.to_sentence
      end
    end

    private

    def set_vehicle
      @vehicle = Vehicle.find(params[:vehicle_id])
    end

    def inspection_params
      params.require(:vehicle_inspection_record).permit(
        :inspection_type,
        :inspection_scope,
        :scheduled_on,
        :completed_on,
        :status,
        :inspector_name,
        :vendor_name,
        :estimated_cost,
        :notes
      )
    end
  end
end
