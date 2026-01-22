class VehicleFinancialSummary
  METRIC_ALIASES = {
    revenue: %w[輸送収入],
    depreciation: %w[減価償却 減価償却費],
    lease: %w[リース費 リース料 リース],
    repair: %w[修繕費 修繕費計],
    fuel: %w[燃料費 燃料費計],
    km: %w[走行Km]
  }.freeze

  attr_reader :vehicle, :from, :to

  def initialize(vehicle:, from: nil, to: nil)
    @vehicle = vehicle
    @from = from
    @to = to
  end

  def totals
    @totals ||= begin
      sums = metric_sums
      METRIC_ALIASES.transform_values do |aliases|
        aliases.sum { |key| sums[key] || 0 }
      end.tap do |result|
        result.default = 0
      end
    end
  end

  def profit
    totals[:revenue] - expense_components.sum
  end

  def revenue_per_km
    km = totals[:km]
    return 0 if km.to_f.zero?

    totals[:revenue] / km
  end

  def monthly_breakdown
    @monthly_breakdown ||= begin
      data = grouped_monthly_sums
      months = data.keys.map(&:first).uniq.sort
      months.map do |month|
        metrics = METRIC_ALIASES.transform_values do |aliases|
          aliases.sum { |key| data[[month, key]] || 0 }
        end
        metrics.default = 0
        metrics[:profit] = metrics[:revenue] - [metrics[:depreciation], metrics[:lease], metrics[:repair]].sum
        metrics[:month] = month
        metrics
      end
    end
  end

  private

  def base_scope
    scope = vehicle.financial_metrics
    scope = scope.where("month >= ?", from) if from.present?
    scope = scope.where("month <= ?", to) if to.present?
    scope
  end

  def metric_sums
    @metric_sums ||= base_scope.group(:metric_key).sum(:value_numeric)
  end

  def grouped_monthly_sums
    @grouped_monthly_sums ||= base_scope.group(:month, :metric_key).sum(:value_numeric)
  end

  def expense_components
    [totals[:depreciation], totals[:lease], totals[:repair]]
  end
end
