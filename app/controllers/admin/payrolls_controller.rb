module Admin
  class PayrollsController < BaseController
    before_action :authorize_admin!

    def index
      @periods = Period.ordered.limit(24)
      if @periods.blank?
        flash.now[:alert] = "対象期間がまだ登録されていません。"
        return
      end

      @period = resolve_period || @periods.first

      @locations = PayrollBatch.where(period: @period).distinct.pluck(:location)
      @locations = PayrollCell.where(period: @period).distinct.pluck(:location) if @locations.empty?
      @locations = @locations.compact.presence || ["default"]

      @location = params[:location].presence || @locations.first

      @column_orders = PayrollColumnOrder.where(period: @period, location: @location).includes(:employee)
      @all_employees = resolve_employees(@column_orders)
      @total_employees = @all_employees.size

      @visible_count = params[:visible_count].to_i
      @visible_count = 13 unless @visible_count.positive?
      @visible_count = @total_employees if @total_employees.positive? && @visible_count > @total_employees
      @visible_count = @total_employees if @total_employees.positive? && @visible_count.zero?

      @start_index = params[:start].to_i
      @start_index = 0 if @start_index.negative?
      if @total_employees.positive? && @visible_count.positive?
        @start_index = (@start_index / @visible_count) * @visible_count
        @start_index = 0 if @start_index >= @total_employees
      else
        @start_index = 0
      end

      @employees = @all_employees.slice(@start_index, @visible_count) || []
      @visible_count_options = build_visible_count_options(@total_employees)
      @window_options = build_window_options(@total_employees, @visible_count)

      @item_orders = ItemOrder.where(period: @period, location: @location).includes(:item)
      @items = resolve_items(@item_orders)

      @cells = PayrollCell.where(period: @period, location: @location).includes(:item, :employee)
      @cell_map = @cells.each_with_object({}) do |cell, hash|
        hash[[cell.item_id, cell.employee_id]] = cell
      end
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

    def build_window_options(total, window)
      return [[display_range_label(1, total), 0]] if total.zero? || window.zero? || total <= window

      options = []
      start = 0
      while start < total
        finish = [start + window, total].min
        options << [display_range_label(start + 1, finish), start]
        start += window
      end
      options
    end

    def build_visible_count_options(total)
      return [13] if total.zero?
      return [total].uniq if total <= 13

      base = [13, 26, 39, 52, total].uniq.sort
      base.select { |count| count.positive? && count <= total }
    end

    def display_range_label(start, finish)
      finish = start if finish < start
      "#{start} - #{finish}"
    end
  end
end
