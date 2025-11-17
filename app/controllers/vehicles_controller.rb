class VehiclesController < ApplicationController
  def index
    @vehicles = Vehicle.ordered
  end

  def show
    @vehicle = Vehicle.find_by(id: params[:id]) ||
               Vehicle.find_by!(call_sign: params[:id]) ||
               Vehicle.find_by!(registration_number: params[:id])
    @financial_summary = VehicleFinancialSummary.new(vehicle: @vehicle)
  end
end
