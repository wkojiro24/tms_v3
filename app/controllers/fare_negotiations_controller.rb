# frozen_string_literal: true

class FareNegotiationsController < ApplicationController
  before_action :set_vehicle_groups
  before_action :set_date_range
  before_action :set_vehicles
  skip_before_action :verify_authenticity_token, only: [:update_external_data]

  def index
    @vehicle_group = VehicleGroup.find_by(id: params[:vehicle_group_id]) if params[:vehicle_group_id].present?
    @selected_vehicle_code = params[:vehicle_code] if params[:vehicle_code].present?

    @include_special = params[:include_special] == "1"

    @service = FareNegotiationDataService.new(
      vehicle_group: @vehicle_group,
      vehicle_code: @selected_vehicle_code,
      start_year: @start_year,
      end_year: @end_year,
      tenant: ActsAsTenant.current_tenant,
      include_special: @include_special
    )

    @yearly_financials = @service.yearly_financials
    @yearly_metrics = @service.yearly_metrics
    @external_comparison = @service.external_comparison
    @simulation_base = @service.simulation_base
    @company_cost_indices = @service.company_cost_indices
    @unit_metrics = @service.unit_metrics

    # シミュレーション実行（パラメータがある場合）
    if params[:simulate].present?
      @simulation_result = @service.simulate(
        labor_increase_rate: params[:labor_increase].to_f,
        fuel_increase_rate: params[:fuel_increase].to_f,
        fare_increase_rate: params[:fare_increase].to_f
      )
    end

    # グラフ用データ
    @chart_data = build_chart_data

    respond_to do |format|
      format.html
      format.xlsx {
        response.headers['Content-Disposition'] = "attachment; filename=\"運賃交渉資料_#{@start_year}-#{@end_year}.xlsx\""
      }
    end
  end

  def update_external_data
    data = params[:external_data] || []

    ExternalEconomicDatum.transaction do
      data.each do |item|
        record = ExternalEconomicDatum.find_or_initialize_by(
          data_type: item[:data_type],
          year: item[:year],
          month: nil
        )
        record.value = item[:value]
        record.save!
      end
    end

    render json: { success: true }
  rescue StandardError => e
    render json: { success: false, error: e.message }, status: :unprocessable_entity
  end

  private

  def set_vehicle_groups
    @vehicle_groups = VehicleGroup.ordered
  end

  def set_date_range
    @start_year = (params[:start_year] || 2020).to_i
    @end_year = (params[:end_year] || Time.current.year).to_i
  end

  def set_vehicles
    @vehicles = VehicleFinancialMetric.where(tenant_id: ActsAsTenant.current_tenant&.id)
                                      .where.not(vehicle_code: %w[99999 88888 77777 66666 55555])
                                      .select(:vehicle_code)
                                      .distinct
                                      .order(:vehicle_code)
                                      .pluck(:vehicle_code)
  end

  def build_chart_data
    years = (@start_year..@end_year).to_a

    # 売上・コスト・損益の推移
    financials_data = {
      labels: years.map { |y| "#{y}期" },
      revenue: years.map { |y| @yearly_financials.dig(y, :revenue)&.round(0) || 0 },
      cost: years.map { |y| @yearly_financials.dig(y, :cost)&.round(0) || 0 },
      profit: years.map { |y| @yearly_financials.dig(y, :profit)&.round(0) || 0 }
    }

    # コスト比率の推移
    metrics_data = {
      labels: years.map { |y| "#{y}期" },
      labor_rate: years.map { |y| @yearly_metrics.dig(y, :labor_cost_rate) || 0 },
      fuel_rate: years.map { |y| @yearly_metrics.dig(y, :fuel_cost_rate) || 0 }
    }

    # 外部指標の推移（基準年=100として指数化）
    base_year = @start_year
    external_series = {}

    ExternalEconomicDatum::DATA_TYPES.keys.each do |type|
      base_value = ExternalEconomicDatum.by_type(type).yearly.find_by(year: base_year)&.value || 100
      external_series[type] = years.map do |year|
        value = ExternalEconomicDatum.by_type(type).yearly.find_by(year: year)&.value
        value.present? ? (value / base_value * 100).round(1) : nil
      end
    end

    # 自社コスト指数を追加
    external_series[:company_labor] = years.map { |y| @company_cost_indices.dig(y, :labor_cost_index) || 100 }
    external_series[:company_fuel] = years.map { |y| @company_cost_indices.dig(y, :fuel_cost_index) || 100 }
    external_series[:company_total] = years.map { |y| @company_cost_indices.dig(y, :total_cost_index) || 100 }

    external_data = {
      labels: years.map { |y| "#{y}年" },
      series: external_series
    }

    {
      financials: financials_data,
      metrics: metrics_data,
      external: external_data
    }
  end
end
