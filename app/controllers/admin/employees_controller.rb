module Admin
  class EmployeesController < BaseController
    helper Admin::PayrollsHelper
    before_action :authorize_admin!
    before_action :set_employee, only: [:show, :payroll, :history]

    def index
      @query = params[:q]
      @status = params[:status]

      @employees = Employee.ordered_by_code
      @employees = @employees.where("full_name ILIKE ? OR employee_code ILIKE ?", "%#{@query}%", "%#{@query}%") if @query.present?
      @employees = @employees.where(current_status: @status) if @status.present?
      @employees = @employees.includes(:assignments, :positions, :statuses).limit(100)
    end

    def show
      @current_assignment = @employee.assignments.current.first
      @current_position = @employee.positions.current.first
      @current_status = @employee.statuses.current.first

      @recent_assignments = @employee.assignments.order(effective_from: :desc).limit(10)
      @recent_positions = @employee.positions.order(effective_from: :desc).limit(10)
      @recent_reviews = @employee.reviews.order(reviewed_on: :desc).limit(5)
      @qualifications = @employee.qualifications.order(expires_on: :asc)
    end

    def payroll
      @period_param = params[:period]&.match?(/\A\d{4}-\d{2}\z/) ? params[:period] : nil
      anchor_date = @period_param ? Date.strptime(@period_param, "%Y-%m") : Date.today

      target_periods =
        Period.where("(year * 100 + month) <= ?", anchor_date.year * 100 + anchor_date.month)
              .order(year: :desc, month: :desc)
              .limit(12)
              .to_a

      @month_entries = build_payroll_month_entries(target_periods)
      @items = Array(determine_item_order(@month_entries))
      @period_options = Period.order(year: :desc, month: :desc).limit(60)
    end

    def history
      @assignments = @employee.assignments.order(effective_from: :desc)
      @positions = @employee.positions.order(effective_from: :desc)
      @statuses = @employee.statuses.order(effective_from: :desc)
      @reviews = @employee.reviews.order(reviewed_on: :desc)
    end

    private

    def authorize_admin!
      authorize! :access, :admin
    end

    def set_employee
      @employee = Employee.find(params[:id])
    end

    def build_payroll_month_entries(periods)
      periods.map do |period|
        cells = PayrollCell.where(period:, employee: @employee)
                           .includes(:item, :payroll_batch)
        cell_map = cells.each_with_object({}) { |cell, hash| hash[cell.item_id] = cell }
        location = cells.first&.location || cells.first&.payroll_batch&.location

        {
          period: period,
          location: location,
          cell_map: cell_map
        }
      end
    end

    def determine_item_order(month_entries)
      month_entries.each do |entry|
        next unless entry[:location].present?

        orders = ItemOrder.where(period: entry[:period], location: entry[:location])
                          .includes(:item)
                          .order(:row_index)
        return orders.map(&:item) if orders.any?
      end

      item_ids = month_entries.flat_map { |entry| entry[:cell_map].keys }.uniq
      return [] if item_ids.blank?

      Item.where(id: item_ids).order(:above_basic, :name)
    end
  end
end
