class VehicleFinancialCategoryTable
  Row = Struct.new(:type, :category, :label, :values, keyword_init: true)

  LABEL_ALIASES = {
    "駐車場・地代" => ["地代家賃"],
    "人件費" => ["ドライバー人件費"],
    "高速代" => ["高速代計"],
    # データ側で「人件費計」として集計されている場合も拾う
    "人件費計" => ["人件費"],
    # 文字種・表記ゆれ吸収
    "地代家賃" => ["駐車場・地代", "地代・家賃"]
  }.freeze
  SUMMARY_LABELS = %w[損益].freeze

  attr_reader :headers, :rows

  def initialize(headers:, rows:, categories: [])
    @headers = headers
    @source_rows = rows
    @categories = Array(categories)
    @column_count = headers.length
    @rows = build_rows
  end

  def column_count
    @column_count
  end

  def item_rows
    @item_rows ||= rows.select { |row| row.type == :item }
  end

  def total_values
    @total_values ||= begin
      sums = Array.new(column_count) { 0.0 }
      item_rows.each do |row|
        row.values.each_with_index do |value, index|
          sums[index] += value.to_f if value.is_a?(Numeric)
        end
      end
      sums
    end
  end

  def average_values
    count = item_rows.count
    return Array.new(column_count) { nil } if count.zero?

    total_values.map do |value|
      value.present? ? (value / count) : nil
    end
  end

  def total_values_sum
    total_values.compact.sum
  end

  def total_average_value
    return nil if column_count.zero?

    total_values_sum / column_count
  end

  def average_values_sum
    average_values.compact.sum
  end

  def average_of_averages
    values = average_values.compact
    return nil if values.empty?

    values.sum / values.length
  end

  def average_summary_value
    average_of_averages
  end

  def net_profit_values(revenue_labels:, cost_labels:)
    revenue_totals, missing_revenue = sum_category_values(revenue_labels)
    cost_totals, missing_costs = sum_category_values(cost_labels)
    missing = (missing_revenue + missing_costs).uniq
    return { values: nil, missing: missing } if revenue_totals.nil? || cost_totals.nil?

    net = revenue_totals.each_with_index.map do |value, index|
      value.to_f - cost_totals[index].to_f
    end
    { values: net, missing: missing }
  end

  def values_for_label(label)
    row = item_rows.find { |r| normalize(r.label) == normalize(label) }
    row&.values
  end

  def category_values_by_display_label(label)
    key = normalize(label)
    totals = Array.new(column_count) { 0.0 }
    found = false

    item_rows.each do |row|
      next unless normalize(row.category&.display_label) == key

      found = true
      row.values.each_with_index do |value, index|
        totals[index] += numeric_value(value)
      end
    end

    return nil unless found

    totals
  end

  private

  def sum_category_values(labels)
    missing = []
    totals = Array.new(column_count) { 0.0 }
    Array(labels).each do |label|
      values = category_values_by_display_label(label)
      if values.nil?
        missing << label
        next
      end

      values.each_with_index do |value, index|
        totals[index] += numeric_value(value)
      end
    end
    [totals, missing]
  end

  def build_rows
    lookup = build_lookup
    collection = []
    @categories.each do |category|
      collection << Row.new(type: :section, category:, label: category.display_label, values: Array.new(column_count))
      category.items.ordered.each do |item|
        collection << Row.new(
          type: :item,
          category: category,
          label: item.display_label,
          values: aggregate_values(item, lookup)
        )
      end
    end
    collection
  end

  def build_lookup
    map = Hash.new { |hash, key| hash[key] = Array.new(column_count) { 0.0 } }
    @source_rows.each do |row|
      normalized = normalize(row[:label])
      values = Array(row[:values])
      summary_row = [:grand_total, :subtotal].include?(row[:row_type])
      if summary_row && !summary_label?(normalized)
        # 明細が存在しない場合だけ小計・合計行を採用する（重複計上防止）
        next if map[normalized].any? { |v| v != 0 }
      end
      map[normalized].each_with_index do |_, index|
        value = values[index]
        map[normalized][index] += value.to_f if value.is_a?(Numeric)
      end
    end
    map
  end

  def aggregate_values(item, lookup)
    values = Array.new(column_count) { 0.0 }
    item.source_label_list.each do |label|
      data = lookup_for_label(lookup, label)
      next unless data

      data.each_with_index do |value, index|
        values[index] += value.to_f if value.is_a?(Numeric)
      end
    end
    values
  end

  def lookup_for_label(lookup, label)
    candidate_keys(label).each do |key|
      return lookup[key] if lookup.key?(key)
    end
    nil
  end

  def candidate_keys(label)
    normalized = normalize(label)
    ([normalized] + alias_keys_for(normalized)).uniq
  end

  def normalize(label)
    label.to_s
         .unicode_normalize(:nfkc)
         .gsub(/[[:space:]]+/, "")
         .gsub(/[・･\/／\-]/, "")
         .downcase
  end

  def numeric_value(value)
    value.is_a?(Numeric) ? value.to_f : 0.0
  end

  def alias_keys_for(normalized_label)
    LABEL_ALIASES.fetch(normalized_label, []).map { |alias_label| normalize(alias_label) }
  end

  def summary_label?(normalized_label)
    @summary_labels ||= SUMMARY_LABELS.map { |label| normalize(label) }
    @summary_labels.include?(normalized_label)
  end
end
