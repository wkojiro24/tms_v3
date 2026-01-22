class TransportOrdersController < ApplicationController
  before_action :set_transport_order, only: [:show, :edit, :update, :destroy]

  def index
    @date = params[:date].present? ? Date.parse(params[:date]) : Date.current
    @transport_orders = TransportOrder.includes(:vehicle, :employee, :shipper, :origin_location, :destination_location)
                                       .where(order_date: @date.beginning_of_month..@date.end_of_month)
                                       .order(:order_date, :id)
    @vehicles = Vehicle.order(:registration_number)
    @employees = Employee.order(:last_name, :first_name)
    @shippers = Shipper.order(:code)
    @destinations = Destination.order(:code)
  end

  def show
    respond_to do |format|
      format.html
      format.json { render json: @transport_order }
    end
  end

  def new
    @transport_order = TransportOrder.new(order_date: Date.current)
  end

  def edit
  end

  def create
    @transport_order = TransportOrder.new(transport_order_params)

    respond_to do |format|
      if @transport_order.save
        format.html { redirect_to transport_orders_path, notice: "運送明細を作成しました。" }
        format.json { render json: @transport_order, status: :created }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: { errors: @transport_order.errors.full_messages }, status: :unprocessable_entity }
      end
    end
  end

  def update
    respond_to do |format|
      if @transport_order.update(transport_order_params)
        format.html { redirect_to transport_orders_path, notice: "運送明細を更新しました。" }
        format.json { render json: @transport_order }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: { errors: @transport_order.errors.full_messages }, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @transport_order.destroy
    respond_to do |format|
      format.html { redirect_to transport_orders_path, notice: "運送明細を削除しました。" }
      format.json { head :no_content }
    end
  end

  def batch_update
    updates = params[:updates] || []
    errors = []

    ActiveRecord::Base.transaction do
      updates.each do |update_data|
        if update_data[:id].present?
          order = TransportOrder.find_by(id: update_data[:id])
          if order
            unless order.update(batch_update_params(update_data))
              errors << { id: update_data[:id], errors: order.errors.full_messages }
            end
          end
        else
          order = TransportOrder.new(batch_update_params(update_data))
          unless order.save
            errors << { row: update_data[:row], errors: order.errors.full_messages }
          end
        end
      end

      raise ActiveRecord::Rollback if errors.any?
    end

    respond_to do |format|
      if errors.empty?
        format.json { render json: { success: true, message: "#{updates.size}件を更新しました。" } }
      else
        format.json { render json: { success: false, errors: errors }, status: :unprocessable_entity }
      end
    end
  end

  private

  def set_transport_order
    @transport_order = TransportOrder.find(params[:id])
  end

  def transport_order_params
    params.require(:transport_order).permit(
      :order_no, :order_date, :vehicle_id, :employee_id, :department_id, :shipper_id,
      :loading_date, :loading_time, :departure_date, :departure_time,
      :arrival_date, :arrival_time, :origin_location_id, :destination_location_id,
      :quantity, :unit, :weight, :distance_km, :driving_km,
      :billing_unit_price, :billing_base_amount, :billing_surcharge,
      :billing_toll, :billing_other, :billing_tax, :billing_total,
      :billing_date, :billing_closing_date,
      :payment_unit_price, :payment_base_amount, :payment_toll, :payment_tax,
      :vehicle_amount, :driver_amount, :remarks, :status
    )
  end

  def batch_update_params(data)
    data.permit(
      :id, :order_no, :order_date, :vehicle_id, :employee_id, :department_id, :shipper_id,
      :loading_date, :loading_time, :departure_date, :departure_time,
      :arrival_date, :arrival_time, :origin_location_id, :destination_location_id,
      :quantity, :unit, :weight, :distance_km, :driving_km,
      :billing_unit_price, :billing_base_amount, :billing_surcharge,
      :billing_toll, :billing_other, :billing_tax, :billing_total,
      :billing_date, :billing_closing_date,
      :payment_unit_price, :payment_base_amount, :payment_toll, :payment_tax,
      :vehicle_amount, :driver_amount, :remarks, :status
    )
  end
end
