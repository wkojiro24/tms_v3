class VehicleGroup < ApplicationRecord
  acts_as_tenant :tenant

  GROUP_TYPES = %w[shipper depot vehicle_type custom].freeze

  validates :name, presence: true
  validates :name, uniqueness: { scope: :tenant_id }
  validates :group_type, inclusion: { in: GROUP_TYPES }

  scope :ordered, -> { order(:position, :name) }
  scope :by_type, ->(type) { where(group_type: type) }

  # 車両コードのリスト（マッピングを適用した正規化済みコード）
  def normalized_vehicle_codes
    codes = Array(vehicle_codes)
    mappings = code_mappings || {}

    # マッピングがある場合は正規コードに変換
    codes.map { |code| mappings[code] || code }.uniq
  end

  # 指定した車両コードがこのグループに含まれるか
  def include_code?(code)
    return false if code.blank?

    normalized = normalize_code(code)
    normalized_vehicle_codes.any? { |c| normalize_code(c) == normalized }
  end

  # 全ての関連車両コードを取得（マッピング元も含む）
  def all_related_codes
    codes = Array(vehicle_codes)
    mappings = code_mappings || {}

    # マッピングの逆引き：正規コード → [元コード1, 元コード2, ...]
    reverse_map = mappings.each_with_object({}) do |(from, to), hash|
      (hash[to] ||= []) << from
    end

    codes.flat_map do |code|
      [code] + (reverse_map[code] || [])
    end.uniq
  end

  # グループタイプの日本語ラベル
  def group_type_label
    case group_type
    when "shipper" then "荷主別"
    when "depot" then "営業所別"
    when "vehicle_type" then "車両種別"
    else "カスタム"
    end
  end

  class << self
    # 荷主別グループを自動生成
    def create_shipper_groups(tenant:)
      shippers = Vehicle.where(tenant_id: tenant.id).distinct.pluck(:shipper_name).compact
      shippers.each do |shipper|
        codes = Vehicle.where(tenant_id: tenant.id, shipper_name: shipper).pluck(:call_sign).compact
        find_or_create_by(tenant: tenant, name: shipper, group_type: "shipper") do |g|
          g.vehicle_codes = codes
        end
      end
    end

    # 営業所別グループを自動生成
    def create_depot_groups(tenant:)
      depots = Vehicle.where(tenant_id: tenant.id).distinct.pluck(:depot_name).compact
      depots.each do |depot|
        codes = Vehicle.where(tenant_id: tenant.id, depot_name: depot).pluck(:call_sign).compact
        find_or_create_by(tenant: tenant, name: depot, group_type: "depot") do |g|
          g.vehicle_codes = codes
        end
      end
    end
  end

  private

  def normalize_code(code)
    code.to_s.unicode_normalize(:nfkc).downcase.gsub(/[－ー]/, "-").strip
  end
end
