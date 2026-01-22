class DashboardController < ApplicationController
  def index
    @today = Date.current

    # 車両サマリー
    @vehicle_stats = {
      total: current_tenant.vehicles.count,
      active: current_tenant.vehicles.where(fault_status: [nil, "none", "運用中"]).count
    }
    @vehicle_stats[:utilization_rate] = @vehicle_stats[:total] > 0 ?
      (@vehicle_stats[:active].to_f / @vehicle_stats[:total] * 100).round(1) : 0

    # 車検期限が近い車両（30日以内）
    # first_registration_on から計算（車検は2年ごと）
    @upcoming_inspections = current_tenant.vehicles
      .where.not(first_registration_on: nil)
      .select { |v| v.first_registration_on && next_inspection_date(v) <= 30.days.from_now }
      .sort_by { |v| next_inspection_date(v) }
      .first(5)

    # 故障・要整備車両
    @vehicles_needing_attention = current_tenant.vehicles
      .where.not(fault_status: [nil, "none", "運用中"])
      .limit(5)

    # 売上サマリー（当月）
    current_month = @today.strftime("%Y%m")
    @revenue_metrics = load_revenue_metrics(current_month)

    # 前月との比較
    last_month = (@today - 1.month).strftime("%Y%m")
    @last_month_metrics = load_revenue_metrics(last_month)

    # ワークフロー（未処理タスク）
    @pending_workflows = current_tenant.workflow_requests
      .where(status: %w[pending submitted in_review])
      .order(created_at: :desc)
      .limit(5)

    # 従業員サマリー
    @employee_stats = {
      total: current_tenant.employees.count,
      active: current_tenant.employees.where(current_status: "active").count
    }

    # お知らせ
    @announcements = current_tenant.announcements
      .published
      .pinned_first
      .limit(5)
  end

  private

  def next_inspection_date(vehicle)
    return nil unless vehicle.first_registration_on

    # 初回車検は3年、以降は2年ごと
    first_reg = vehicle.first_registration_on
    first_inspection = first_reg + 3.years

    if @today < first_inspection
      first_inspection
    else
      years_since_first = ((@today - first_inspection) / 365.25).floor
      first_inspection + ((years_since_first / 2 + 1) * 2).years
    end
  end

  def load_revenue_metrics(month)
    metrics = VehicleFinancialMetric.where(month: month)

    revenue = metrics.where(metric_key: "輸送収入").sum(:value_numeric)
    vehicle_cost = metrics.where(metric_key: "車両費").sum(:value_numeric)
    profit = metrics.where(metric_key: "車両利益").sum(:value_numeric)

    {
      revenue: revenue,
      vehicle_cost: vehicle_cost,
      profit: profit,
      vehicle_count: metrics.select(:vehicle_code).distinct.count
    }
  end
end
