# frozen_string_literal: true

class FareNegotiationDataService
  attr_reader :vehicle_group, :vehicle_code, :start_year, :end_year, :tenant, :include_special

  def initialize(vehicle_group: nil, vehicle_code: nil, start_year: 2019, end_year: Time.current.year, tenant: ActsAsTenant.current_tenant, include_special: false)
    @vehicle_group = vehicle_group
    @vehicle_code = vehicle_code
    @start_year = start_year
    @end_year = end_year
    @tenant = tenant
    @include_special = include_special
  end

  # 年度別の売上・コスト・損益を集計
  def yearly_financials
    @yearly_financials ||= calculate_yearly_financials
  end

  # 年度別の主要指標（人件費率、燃料費率など）
  def yearly_metrics
    @yearly_metrics ||= calculate_yearly_metrics
  end

  # 外部データとの比較用データ
  def external_comparison
    @external_comparison ||= build_external_comparison
  end

  # シミュレーション用のベースデータ（直近年度）
  def simulation_base
    @simulation_base ||= build_simulation_base
  end

  # シミュレーション実行
  def simulate(labor_increase_rate: 0, fuel_increase_rate: 0, fare_increase_rate: 0)
    base = simulation_base
    return nil if base.nil?

    labor_cost = base[:labor_cost] * (1 + labor_increase_rate / 100.0)
    fuel_cost = base[:fuel_cost] * (1 + fuel_increase_rate / 100.0)
    other_cost = base[:other_cost]
    revenue = base[:revenue] * (1 + fare_increase_rate / 100.0)

    total_cost = labor_cost + fuel_cost + other_cost
    profit = revenue - total_cost

    {
      revenue: revenue.round(0),
      labor_cost: labor_cost.round(0),
      fuel_cost: fuel_cost.round(0),
      other_cost: other_cost.round(0),
      total_cost: total_cost.round(0),
      profit: profit.round(0),
      profit_rate: revenue.positive? ? (profit / revenue * 100).round(1) : 0,
      profit_change: (profit - base[:profit]).round(0)
    }
  end

  # 自社コストの指数推移（基準年=100）
  def company_cost_indices
    @company_cost_indices ||= calculate_company_cost_indices
  end

  # 単価指標（1台あたり、1人あたり）
  def unit_metrics
    @unit_metrics ||= calculate_unit_metrics
  end

  private

  def calculate_unit_metrics
    result = {}
    (start_year..end_year).each do |year|
      data = fiscal_year_data(year)
      vehicle_count = count_vehicles_for_year(year)
      driver_count = count_drivers_for_year(year)

      result[year] = {
        vehicle_count: vehicle_count,
        driver_count: driver_count,
        # 1台あたり
        revenue_per_vehicle: vehicle_count.positive? ? (data[:revenue] / vehicle_count).round(0) : 0,
        cost_per_vehicle: vehicle_count.positive? ? (data[:cost] / vehicle_count).round(0) : 0,
        profit_per_vehicle: vehicle_count.positive? ? (data[:profit] / vehicle_count).round(0) : 0,
        # 1人あたり
        revenue_per_driver: driver_count.positive? ? (data[:revenue] / driver_count).round(0) : 0,
        cost_per_driver: driver_count.positive? ? (data[:cost] / driver_count).round(0) : 0,
        profit_per_driver: driver_count.positive? ? (data[:profit] / driver_count).round(0) : 0
      }
    end
    result
  end

  def count_vehicles_for_year(year)
    # 決算期は9月〜8月
    start_month = Date.new(year - 1, 9, 1)
    end_month = Date.new(year, 8, 1)

    scope = VehicleFinancialMetric.where(tenant_id: tenant&.id)
                                  .where(month: start_month..end_month)

    if vehicle_group.present?
      vehicle_codes = vehicle_group.all_related_codes
      scope = scope.where(vehicle_code: vehicle_codes) if vehicle_codes.present?
    end

    # 集計用特殊コードを除外（include_specialがfalseの場合のみ）
    scope = scope.where.not(vehicle_code: special_codes) unless include_special

    scope.select(:vehicle_code).distinct.count
  end

  def count_drivers_for_year(year)
    # 簡易的にドライバー数を推定（車両数 * 1.2 or 実際のドライバーデータがあれば使用）
    # まずはVehicleモデルからドライバー情報を取得を試みる
    if vehicle_group.present?
      vehicle_codes = vehicle_group.all_related_codes
      Vehicle.where(tenant_id: tenant&.id, call_sign: vehicle_codes).count
    else
      Vehicle.where(tenant_id: tenant&.id).count
    end
  end

  def calculate_yearly_financials
    result = {}
    (start_year..end_year).each do |year|
      data = fiscal_year_data(year)
      result[year] = {
        revenue: data[:revenue],
        labor_cost: data[:labor_cost],
        fuel_cost: data[:fuel_cost],
        cost: data[:cost],
        profit: data[:profit],
        profit_rate: data[:revenue].positive? ? (data[:profit] / data[:revenue] * 100).round(1) : 0
      }
    end
    result
  end

  def calculate_yearly_metrics
    result = {}
    (start_year..end_year).each do |year|
      data = fiscal_year_data(year)
      revenue = data[:revenue]

      # その他コスト率を計算
      other_cost = data[:cost] - data[:labor_cost] - data[:fuel_cost]
      other_cost_rate = revenue.positive? ? (other_cost / revenue * 100).round(1) : 0

      result[year] = {
        labor_cost_rate: revenue.positive? ? (data[:labor_cost] / revenue * 100).round(1) : 0,
        fuel_cost_rate: revenue.positive? ? (data[:fuel_cost] / revenue * 100).round(1) : 0,
        other_cost_rate: other_cost_rate,
        vehicle_cost_rate: revenue.positive? ? (data[:vehicle_cost] / revenue * 100).round(1) : 0,
        km_unit_price: data[:total_km].positive? ? (revenue / data[:total_km]).round(1) : 0
      }
    end
    result
  end

  def calculate_company_cost_indices
    base_year_data = fiscal_year_data(start_year)
    return {} if base_year_data[:labor_cost].zero? || base_year_data[:fuel_cost].zero?

    result = {}
    (start_year..end_year).each do |year|
      data = fiscal_year_data(year)

      # 人件費指数（基準年=100）
      labor_index = base_year_data[:labor_cost].positive? ?
        (data[:labor_cost] / base_year_data[:labor_cost] * 100).round(1) : 100

      # 燃料費指数（基準年=100）
      fuel_index = base_year_data[:fuel_cost].positive? ?
        (data[:fuel_cost] / base_year_data[:fuel_cost] * 100).round(1) : 100

      # 総コスト指数（基準年=100）
      total_cost_index = base_year_data[:cost].positive? ?
        (data[:cost] / base_year_data[:cost] * 100).round(1) : 100

      result[year] = {
        labor_cost_index: labor_index,
        fuel_cost_index: fuel_index,
        total_cost_index: total_cost_index
      }
    end
    result
  end

  def fiscal_year_data(year)
    # 決算期は9月〜8月
    start_month = Date.new(year - 1, 9, 1)
    end_month = Date.new(year, 8, 1)

    scope = VehicleFinancialMetric.where(tenant_id: tenant&.id)
                                   .where(month: start_month..end_month)

    # 車両コード指定がある場合（単体車両）
    if vehicle_code.present?
      scope = scope.where(vehicle_code: vehicle_code)
    elsif vehicle_group.present?
      vehicle_codes = vehicle_group.all_related_codes
      scope = scope.where(vehicle_code: vehicle_codes) if vehicle_codes.present?
    end

    # 集計用特殊コードを除外（include_specialがfalseの場合のみ）
    scope = scope.where.not(vehicle_code: special_codes) unless include_special

    # 各項目を集計
    revenue = sum_by_labels(scope, %w[輸送収入 輸送収入計])
    labor_cost = sum_by_labels(scope, %w[人件費計 ドライバー人件費 営業所人件費 本社人件費])
    fuel_cost = sum_by_labels(scope, %w[燃料費計 軽油費])
    vehicle_cost = sum_by_labels(scope, %w[車両費計 減価償却費])
    profit = sum_by_labels(scope, %w[損益])
    total_km = sum_by_labels(scope, %w[走行Km 走行km])

    # 総コストは「売上−損益」で計算（輸送原価計には本社費用が含まれないため）
    total_cost = profit.nonzero? ? (revenue - profit) : sum_by_labels(scope, %w[輸送原価計])

    {
      revenue: revenue,
      labor_cost: labor_cost,
      fuel_cost: fuel_cost,
      vehicle_cost: vehicle_cost,
      cost: total_cost,
      profit: profit.nonzero? || (revenue - total_cost),
      total_km: total_km
    }
  end

  def sum_by_labels(scope, labels)
    scope.where(metric_label: labels).sum(:value_numeric).to_f
  end

  def special_codes
    %w[99999 88888 77777 66666 55555]
  end

  def build_external_comparison
    base_year = start_year
    latest_year = end_year

    {
      minimum_wage: {
        base: ExternalEconomicDatum.by_type("minimum_wage").yearly.find_by(year: base_year)&.value,
        latest: ExternalEconomicDatum.by_type("minimum_wage").yearly.find_by(year: latest_year)&.value,
        change_rate: ExternalEconomicDatum.change_rate_from_base("minimum_wage", base_year: base_year, target_year: latest_year)
      },
      diesel_price: {
        base: ExternalEconomicDatum.by_type("diesel_price").yearly.find_by(year: base_year)&.value,
        latest: ExternalEconomicDatum.by_type("diesel_price").yearly.find_by(year: latest_year)&.value,
        change_rate: ExternalEconomicDatum.change_rate_from_base("diesel_price", base_year: base_year, target_year: latest_year)
      },
      truck_price: {
        base: ExternalEconomicDatum.by_type("truck_price").yearly.find_by(year: base_year)&.value,
        latest: ExternalEconomicDatum.by_type("truck_price").yearly.find_by(year: latest_year)&.value,
        change_rate: ExternalEconomicDatum.change_rate_from_base("truck_price", base_year: base_year, target_year: latest_year)
      },
      driver_wage: {
        base: ExternalEconomicDatum.by_type("driver_wage").yearly.find_by(year: base_year)&.value,
        latest: ExternalEconomicDatum.by_type("driver_wage").yearly.find_by(year: latest_year)&.value,
        change_rate: ExternalEconomicDatum.change_rate_from_base("driver_wage", base_year: base_year, target_year: latest_year)
      }
    }
  end

  def build_simulation_base
    data = fiscal_year_data(end_year)
    return nil if data[:revenue].zero?

    other_cost = data[:cost] - data[:labor_cost] - data[:fuel_cost]
    # シミュレーションでは revenue - total_cost で損益を計算するため、
    # ベースデータも同じ計算方法で統一する（データベースの損益ラベルの値は使わない）
    calculated_profit = data[:revenue] - data[:cost]

    {
      year: end_year,
      revenue: data[:revenue],
      labor_cost: data[:labor_cost],
      fuel_cost: data[:fuel_cost],
      other_cost: other_cost,
      total_cost: data[:cost],
      profit: calculated_profit
    }
  end
end
