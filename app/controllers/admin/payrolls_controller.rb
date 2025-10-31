module Admin
  class PayrollsController < BaseController
    before_action :authorize_admin!

    def index
      @period = resolve_period
      return unless @period

      @locations = PayrollBatch.where(period: @period).distinct.pluck(:location)
      @locations = PayrollCell.where(period: @period).distinct.pluck(:location) if @locations.empty?
      @locations = @locations.compact.presence || ["default"]

      @location = params[:location].presence || @locations.first

      @column_orders = PayrollColumnOrder.where(period: @period, location: @location).includes(:employee)
      @employees = resolve_employees(@column_orders)

      @item_orders = ItemOrder.where(period: @period, location: @location).includes(:item)
      @items = resolve_items(@item_orders)

      @cells = PayrollCell.where(period: @period, location: @location).includes(:item, :employee)
      @cell_map = @cells.each_with_object({}) do |cell, hash|
        hash[[cell.item_id, cell.employee_id]] = cell
      end

      @periods = Period.ordered.limit(24)
    end

    def destroy
      period = Period.find(params[:period_id])
      location = params[:location].presence

      PayrollCell.where(period:, location: location).delete_all
      ItemOrder.where(period:, location: location).delete_all
      PayrollColumnOrder.where(period:, location: location).delete_all
      PayrollBatch.where(period:, location: location).delete_all

      redirect_to admin_payrolls_path(period_id: period.id),
                  notice: "#{period.label} #{location || 'default'} の給与データを削除しました。"
    end

    private

    def authorize_admin!
      authorize! :access, :admin
    end

    def resolve_period
      if params[:period_id].present?
        Period.find_by(id: params[:period_id])
      elsif params[:target_month].present? && params[:target_month].match?(/\A\d{4}-\d{2}\z/)
        year, month = params[:target_month].split("-").map(&:to_i)
        Period.find_by(year:, month:)
      else
        Period.order(year: :desc, month: :desc).first
      end
    end

    def resolve_employees(column_orders)
      if column_orders.any?
        column_orders.map(&:employee)
      else
        PayrollCell.where(period: @period, location: @location)
                   .includes(:employee)
                   .map(&:employee)
                   .uniq
                   .sort_by(&:employee_code)
      end
    end

    def resolve_items(item_orders)
      if item_orders.any?
        item_orders.map(&:item)
      else
        PayrollCell.where(period: @period, location: @location)
                   .includes(:item)
                   .map(&:item)
                   .uniq
                   .sort_by(&:name)
      end
    end
  end
end
