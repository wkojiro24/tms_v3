# frozen_string_literal: true

# 外部経済データのシード
# 出典:
# - 最低賃金: 厚生労働省
# - 軽油価格: 資源エネルギー庁
# - 大型トラック価格: 日本自動車工業会
# - 消費者物価指数: 総務省統計局

puts "=== Seeding External Economic Data ==="

# 最低賃金（全国加重平均）
minimum_wages = {
  2015 => 798,
  2016 => 823,
  2017 => 848,
  2018 => 874,
  2019 => 901,
  2020 => 902,  # コロナで据え置き
  2021 => 930,
  2022 => 961,
  2023 => 1004,
  2024 => 1055,
  2025 => 1100  # 予測値
}

minimum_wages.each do |year, value|
  ExternalEconomicDatum.find_or_create_by!(
    data_type: "minimum_wage",
    year: year,
    month: nil
  ) do |d|
    d.value = value
    d.source = "厚生労働省"
    d.notes = "全国加重平均"
  end
end
puts "  最低賃金: #{minimum_wages.size}件"

# 軽油価格（円/L、年平均）
diesel_prices = {
  2015 => 109,
  2016 => 97,
  2017 => 107,
  2018 => 121,
  2019 => 119,
  2020 => 105,
  2021 => 123,
  2022 => 152,
  2023 => 148,
  2024 => 155,
  2025 => 158  # 予測値
}

diesel_prices.each do |year, value|
  ExternalEconomicDatum.find_or_create_by!(
    data_type: "diesel_price",
    year: year,
    month: nil
  ) do |d|
    d.value = value
    d.source = "資源エネルギー庁"
    d.notes = "年間平均価格"
  end
end
puts "  軽油価格: #{diesel_prices.size}件"

# 大型トラック価格指数（2015年=100）
truck_prices = {
  2015 => 100.0,
  2016 => 101.2,
  2017 => 102.5,
  2018 => 104.3,
  2019 => 106.8,
  2020 => 108.5,
  2021 => 112.3,
  2022 => 118.7,
  2023 => 125.4,
  2024 => 132.1,
  2025 => 138.5  # 予測値
}

truck_prices.each do |year, value|
  ExternalEconomicDatum.find_or_create_by!(
    data_type: "truck_price",
    year: year,
    month: nil
  ) do |d|
    d.value = value
    d.source = "日本自動車工業会"
    d.notes = "大型トラック価格指数（2015年=100）"
  end
end
puts "  大型トラック価格: #{truck_prices.size}件"

# 消費者物価指数（2020年=100）
cpi_values = {
  2015 => 98.2,
  2016 => 98.1,
  2017 => 98.6,
  2018 => 99.5,
  2019 => 100.0,
  2020 => 100.0,
  2021 => 99.8,
  2022 => 102.3,
  2023 => 105.6,
  2024 => 108.2,
  2025 => 110.5  # 予測値
}

cpi_values.each do |year, value|
  ExternalEconomicDatum.find_or_create_by!(
    data_type: "cpi",
    year: year,
    month: nil
  ) do |d|
    d.value = value
    d.source = "総務省統計局"
    d.notes = "消費者物価指数（2020年=100）"
  end
end
puts "  消費者物価指数: #{cpi_values.size}件"

# トラック運転者年収（万円）
driver_wages = {
  2015 => 399,
  2016 => 403,
  2017 => 415,
  2018 => 420,
  2019 => 431,
  2020 => 427,
  2021 => 435,
  2022 => 449,
  2023 => 463,
  2024 => 480,
  2025 => 498  # 予測値
}

driver_wages.each do |year, value|
  ExternalEconomicDatum.find_or_create_by!(
    data_type: "driver_wage",
    year: year,
    month: nil
  ) do |d|
    d.value = value
    d.source = "厚生労働省 賃金構造基本統計調査"
    d.notes = "大型トラック運転者の年収（万円）"
  end
end
puts "  トラック運転者賃金: #{driver_wages.size}件"

puts "=== External Economic Data Seeding Complete ==="
puts "Total: #{ExternalEconomicDatum.count}件"
