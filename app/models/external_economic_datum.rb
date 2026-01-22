# frozen_string_literal: true

class ExternalEconomicDatum < ApplicationRecord
  self.table_name = "external_economic_data"

  # データタイプ
  DATA_TYPES = {
    minimum_wage: "最低賃金",
    diesel_price: "軽油価格",
    truck_price: "大型トラック価格",
    cpi: "消費者物価指数",
    driver_wage: "トラック運転者賃金"
  }.freeze

  validates :data_type, presence: true, inclusion: { in: DATA_TYPES.keys.map(&:to_s) }
  validates :year, presence: true
  validates :value, presence: true

  scope :by_type, ->(type) { where(data_type: type) }
  scope :by_year_range, ->(start_year, end_year) { where(year: start_year..end_year) }
  scope :yearly, -> { where(month: nil) }
  scope :monthly, -> { where.not(month: nil) }

  def self.type_label(type)
    DATA_TYPES[type.to_sym] || type
  end

  # 年度別のデータを取得（グラフ用）
  def self.yearly_series(data_type, start_year: 2015, end_year: Time.current.year)
    by_type(data_type)
      .yearly
      .by_year_range(start_year, end_year)
      .order(:year)
      .pluck(:year, :value)
      .to_h
  end

  # 月次データを取得（グラフ用）
  def self.monthly_series(data_type, start_year: 2015, end_year: Time.current.year)
    by_type(data_type)
      .monthly
      .by_year_range(start_year, end_year)
      .order(:year, :month)
      .map { |d| ["#{d.year}-#{d.month.to_s.rjust(2, '0')}", d.value] }
      .to_h
  end

  # 基準年からの変化率を計算
  def self.change_rate_from_base(data_type, base_year:, target_year:)
    base_value = by_type(data_type).yearly.find_by(year: base_year)&.value
    target_value = by_type(data_type).yearly.find_by(year: target_year)&.value

    return nil if base_value.nil? || target_value.nil? || base_value.zero?

    ((target_value - base_value) / base_value * 100).round(1)
  end
end
