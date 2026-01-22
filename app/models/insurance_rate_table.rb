class InsuranceRateTable < ApplicationRecord
  belongs_to :tenant, optional: true

  validates :year, presence: true

  scope :active, -> { where(active: true) }
  scope :for_year, ->(year) { where(year: year) }
  scope :for_prefecture, ->(pref) { where(prefecture: [pref, nil]) }

  # 2024年度デフォルト料率（従業員負担分）
  DEFAULT_RATES = {
    health_insurance_rate: 5.0,      # 健康保険 約10%の半分
    nursing_insurance_rate: 0.91,    # 介護保険 約1.82%の半分（40歳以上）
    pension_rate: 9.15,              # 厚生年金 18.3%の半分
    employment_insurance_rate: 0.6   # 雇用保険 0.6%（一般事業）
  }.freeze

  def self.rates_for(year, prefecture = nil)
    table = active.for_year(year).for_prefecture(prefecture).first
    return DEFAULT_RATES unless table

    {
      health_insurance_rate: table.health_insurance_rate || DEFAULT_RATES[:health_insurance_rate],
      nursing_insurance_rate: table.nursing_insurance_rate || DEFAULT_RATES[:nursing_insurance_rate],
      pension_rate: table.pension_rate || DEFAULT_RATES[:pension_rate],
      employment_insurance_rate: table.employment_insurance_rate || DEFAULT_RATES[:employment_insurance_rate]
    }
  end
end
