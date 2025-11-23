require "csv"

class VehicleImporter
  HEADER_MAP = {
    depot_name: "営業所",
    registration_number: "自動車登録番号",
    call_sign: "呼称",
    first_registration_on: "初度",
    age_text: "経過年数",
    model_code: "型式",
    manufacturer_name: "車名",
    chassis_number: "車台番号",
    vehicle_category: "種別",
    max_load_kg: "最大積載量",
    gross_weight_kg: "車両総重量",
    chassis_base: "シャーシ　ベース",
    pto: "PTO",
    shipper_name: "荷主",
    cargo_name: "輸送品名",
    specific_gravity: "比重",
    tank_made_on: "タンク製造年月日",
    tank_age_text: "タンク経過年数",
    hatch_pattern: "ハッチ割",
    tank_material: "タンク材質",
    tank_manufacturer: "タンク製造元",
    tire_count: "タイヤ本数",
    notes: "備考",
    body_type: "車体形状",
    usage_category: "タンク材質"
  }.freeze

  def initialize(csv_path)
    @csv_path = csv_path
  end

  def import!
    return unless File.exist?(@csv_path)

    CSV.foreach(@csv_path, headers: true, encoding: "bom|utf-8") do |row|
      attrs = build_attributes(row)
      next if attrs[:registration_number].blank?

      Vehicle.find_or_initialize_by(
        registration_number: attrs[:registration_number],
        first_registration_on: attrs[:first_registration_on]
      ).tap do |vehicle|
        vehicle.assign_attributes(attrs)
        vehicle.save!
      end
    end
  end

  private

  def build_attributes(row)
    attrs = {}
    HEADER_MAP.each do |key, header|
      attrs[key] = fetch_value(row, header)&.strip
    end

    attrs[:first_registration_on] = parse_month(attrs[:first_registration_on])
    attrs[:tank_made_on] = parse_month(attrs[:tank_made_on])
    attrs[:max_load_kg] = parse_number(attrs[:max_load_kg])
    attrs[:gross_weight_kg] = parse_number(attrs[:gross_weight_kg])
    attrs[:tire_count] = parse_number(attrs[:tire_count])
    attrs[:usage_category] = fetch_value(row, "タンク材質", 1)&.strip if attrs[:usage_category].blank?
    attrs[:metadata] = { original: row.to_h }

    attrs
  end

  def fetch_value(row, header, offset = 0)
    row.field(header, offset)
  end

  def parse_month(value)
    return if value.blank?

    normalized = value.tr("０-９", "0-9")
    if normalized =~ /(\d{4})年(\d{1,2})月/
      Date.new($1.to_i, $2.to_i, 1)
    end
  rescue ArgumentError
    nil
  end

  def parse_number(value)
    return if value.blank?

    str = value.to_s.tr("０-９", "0-9").gsub(/[^\d]/, "")
    str.present? ? str.to_i : nil
  end
end
