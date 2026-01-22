# 標準報酬月額テーブル
# 健康保険・厚生年金の保険料計算に使用
# 参考: https://www.kyoukaikenpo.or.jp/g3/cat330/sb3150/r05/r5ryougakuhyou3gatukara/
class StandardMonthlyRemuneration < ApplicationRecord
  belongs_to :tenant, optional: true

  validates :year, presence: true
  validates :grade, presence: true
  validates :monthly_amount, presence: true

  scope :for_year, ->(year) { where(year: year) }
  scope :active, -> { where(active: true) }

  # 報酬月額から標準報酬月額等級を決定
  # @param monthly_salary [Integer] 報酬月額（通勤手当含む総支給額）
  # @param year [Integer] 対象年度
  # @return [StandardMonthlyRemuneration] 該当する等級
  def self.find_grade_for(monthly_salary, year)
    table = for_year(year).active.order(:grade)

    # 該当する等級を探す（報酬月額の範囲で判定）
    table.find do |grade|
      monthly_salary >= grade.lower_limit && monthly_salary < grade.upper_limit
    end || table.last # 上限を超えた場合は最高等級
  end

  # 2025年度の標準報酬月額テーブル（健康保険）
  # 協会けんぽ・福島県の場合
  HEALTH_INSURANCE_2025 = [
    # [等級, 標準報酬月額, 下限, 上限]
    [1, 58_000, 0, 63_000],
    [2, 68_000, 63_000, 73_000],
    [3, 78_000, 73_000, 83_000],
    [4, 88_000, 83_000, 93_000],
    [5, 98_000, 93_000, 101_000],
    [6, 104_000, 101_000, 107_000],
    [7, 110_000, 107_000, 114_000],
    [8, 118_000, 114_000, 122_000],
    [9, 126_000, 122_000, 130_000],
    [10, 134_000, 130_000, 138_000],
    [11, 142_000, 138_000, 146_000],
    [12, 150_000, 146_000, 155_000],
    [13, 160_000, 155_000, 165_000],
    [14, 170_000, 165_000, 175_000],
    [15, 180_000, 175_000, 185_000],
    [16, 190_000, 185_000, 195_000],
    [17, 200_000, 195_000, 210_000],
    [18, 220_000, 210_000, 230_000],
    [19, 240_000, 230_000, 250_000],
    [20, 260_000, 250_000, 270_000],
    [21, 280_000, 270_000, 290_000],
    [22, 300_000, 290_000, 310_000],
    [23, 320_000, 310_000, 330_000],
    [24, 340_000, 330_000, 350_000],
    [25, 360_000, 350_000, 370_000],
    [26, 380_000, 370_000, 395_000],
    [27, 410_000, 395_000, 425_000],
    [28, 440_000, 425_000, 455_000],
    [29, 470_000, 455_000, 485_000],
    [30, 500_000, 485_000, 515_000],
    [31, 530_000, 515_000, 545_000],
    [32, 560_000, 545_000, 575_000],
    [33, 590_000, 575_000, 605_000],
    [34, 620_000, 605_000, 635_000],
    [35, 650_000, 635_000, 665_000],
    [36, 680_000, 665_000, 695_000],
    [37, 710_000, 695_000, 730_000],
    [38, 750_000, 730_000, 770_000],
    [39, 790_000, 770_000, 810_000],
    [40, 830_000, 810_000, 855_000],
    [41, 880_000, 855_000, 905_000],
    [42, 930_000, 905_000, 955_000],
    [43, 980_000, 955_000, 1_005_000],
    [44, 1_030_000, 1_005_000, 1_055_000],
    [45, 1_090_000, 1_055_000, 1_115_000],
    [46, 1_150_000, 1_115_000, 1_175_000],
    [47, 1_210_000, 1_175_000, 1_235_000],
    [48, 1_270_000, 1_235_000, 1_295_000],
    [49, 1_330_000, 1_295_000, 1_355_000],
    [50, 1_390_000, 1_355_000, 999_999_999]
  ].freeze

  # 厚生年金の等級テーブル（健康保険とは異なる）
  # 厚生年金は1等級〜32等級（上限650,000円）
  PENSION_2025 = [
    [1, 88_000, 0, 93_000],
    [2, 98_000, 93_000, 101_000],
    [3, 104_000, 101_000, 107_000],
    [4, 110_000, 107_000, 114_000],
    [5, 118_000, 114_000, 122_000],
    [6, 126_000, 122_000, 130_000],
    [7, 134_000, 130_000, 138_000],
    [8, 142_000, 138_000, 146_000],
    [9, 150_000, 146_000, 155_000],
    [10, 160_000, 155_000, 165_000],
    [11, 170_000, 165_000, 175_000],
    [12, 180_000, 175_000, 185_000],
    [13, 190_000, 185_000, 195_000],
    [14, 200_000, 195_000, 210_000],
    [15, 220_000, 210_000, 230_000],
    [16, 240_000, 230_000, 250_000],
    [17, 260_000, 250_000, 270_000],
    [18, 280_000, 270_000, 290_000],
    [19, 300_000, 290_000, 310_000],
    [20, 320_000, 310_000, 330_000],
    [21, 340_000, 330_000, 350_000],
    [22, 360_000, 350_000, 370_000],
    [23, 380_000, 370_000, 395_000],
    [24, 410_000, 395_000, 425_000],
    [25, 440_000, 425_000, 455_000],
    [26, 470_000, 455_000, 485_000],
    [27, 500_000, 485_000, 515_000],
    [28, 530_000, 515_000, 545_000],
    [29, 560_000, 545_000, 575_000],
    [30, 590_000, 575_000, 605_000],
    [31, 620_000, 605_000, 635_000],
    [32, 650_000, 635_000, 999_999_999]
  ].freeze

  # 標準報酬月額から健康保険料を計算（福島県・2025年度）
  # @param standard_monthly [Integer] 標準報酬月額
  # @param include_nursing [Boolean] 介護保険を含むか（40歳以上）
  # @return [Hash] { health: 健康保険料, nursing: 介護保険料 }
  def self.calculate_health_insurance(standard_monthly, include_nursing: true, year: 2025, prefecture: '福島')
    rates = prefecture_rates(year, prefecture)

    health = (standard_monthly * rates[:health_rate] / 1000).round
    nursing = include_nursing ? (standard_monthly * rates[:nursing_rate] / 1000).round : 0

    { health: health, nursing: nursing }
  end

  # 標準報酬月額から厚生年金保険料を計算
  # @param standard_monthly [Integer] 標準報酬月額（厚生年金用）
  # @return [Integer] 厚生年金保険料（本人負担分）
  def self.calculate_pension(standard_monthly, year: 2025)
    # 厚生年金保険料率: 18.3%（労使折半で9.15%）
    (standard_monthly * 91.5 / 1000).round
  end

  # 報酬月額から雇用保険料を計算
  # @param gross_salary [Integer] 総支給額
  # @return [Integer] 雇用保険料
  def self.calculate_employment_insurance(gross_salary, year: 2025)
    # 雇用保険料率（一般事業）: 0.6%
    (gross_salary * 6 / 1000).round
  end

  # 都道府県別の保険料率（千分率）
  # 協会けんぽ 2025年度
  PREFECTURE_RATES = {
    # 福島県 10.20% / 2 = 5.10%
    'fukushima' => { health_rate: 51.0, nursing_rate: 9.0 },
    # 東京都 9.98% / 2 = 4.99%
    'tokyo' => { health_rate: 49.8, nursing_rate: 9.0 },
  }.freeze

  def self.prefecture_rates(year, prefecture = nil)
    # 都道府県名を正規化（日本語/英語対応）
    normalized = normalize_prefecture(prefecture)
    PREFECTURE_RATES[normalized] || { health_rate: 51.0, nursing_rate: 9.0 }  # デフォルトは福島
  end

  def self.normalize_prefecture(prefecture)
    return 'fukushima' if prefecture.nil? || prefecture.to_s.empty?

    name = prefecture.to_s.encode('UTF-8', invalid: :replace, undef: :replace).downcase
    case
    when name.include?('fukushima'), name.bytes == [231, 166, 143, 229, 179, 182]  # 福島
      'fukushima'
    when name.include?('tokyo'), name.bytes == [230, 157, 177, 228, 186, 172]  # 東京
      'tokyo'
    else
      'fukushima'  # デフォルト
    end
  end

  # 報酬月額から該当する健康保険等級を返す
  def self.health_grade_for(monthly_salary, year: 2025)
    HEALTH_INSURANCE_2025.find do |grade, amount, lower, upper|
      monthly_salary >= lower && monthly_salary < upper
    end || HEALTH_INSURANCE_2025.last
  end

  # 報酬月額から該当する厚生年金等級を返す
  def self.pension_grade_for(monthly_salary, year: 2025)
    PENSION_2025.find do |grade, amount, lower, upper|
      monthly_salary >= lower && monthly_salary < upper
    end || PENSION_2025.last
  end

  # 報酬月額から全ての社会保険料を計算
  # @param monthly_salary [Integer] 報酬月額（総支給額）
  # @param include_nursing [Boolean] 介護保険を含むか（40歳以上）
  # @return [Hash] 各保険料
  def self.calculate_all(monthly_salary, include_nursing: true, year: 2025, prefecture: '福島')
    # 健康保険の標準報酬月額を決定
    health_grade = health_grade_for(monthly_salary, year: year)
    health_standard = health_grade[1]

    # 厚生年金の標準報酬月額を決定（上限が異なる）
    pension_grade = pension_grade_for(monthly_salary, year: year)
    pension_standard = pension_grade[1]

    health_result = calculate_health_insurance(health_standard, include_nursing: include_nursing, year: year, prefecture: prefecture)

    {
      health_standard_monthly: health_standard,
      pension_standard_monthly: pension_standard,
      health_insurance: health_result[:health],
      nursing_insurance: health_result[:nursing],
      pension_insurance: calculate_pension(pension_standard, year: year),
      employment_insurance: calculate_employment_insurance(monthly_salary, year: year),
      health_grade: health_grade[0],
      pension_grade: pension_grade[0]
    }
  end
end
