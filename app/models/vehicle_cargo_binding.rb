class VehicleCargoBinding < ApplicationRecord
  include TenantScoped

  belongs_to :vehicle
  belongs_to :shipper, optional: true
  belongs_to :default_origin, class_name: "Destination", optional: true
  belongs_to :default_destination, class_name: "Destination", optional: true

  validates :cargo_name, presence: true
  validates :vehicle_id, uniqueness: { scope: [:tenant_id, :cargo_name], message: "は既にこの荷物に紐付けられています" }

  scope :default_bindings, -> { where(is_default: true) }
  scope :by_category, ->(category) { where(cargo_category: category) }
  scope :for_vehicle, ->(vehicle) { where(vehicle: vehicle) }
  scope :ordered, -> { order(:priority, :cargo_name) }

  # 特定の車両に対するデフォルト荷物設定を取得
  def self.default_for_vehicle(vehicle)
    default_bindings.for_vehicle(vehicle).ordered.first
  end

  # カテゴリ一覧を取得
  def self.categories
    distinct.where.not(cargo_category: [nil, ""]).pluck(:cargo_category).sort
  end

  # 車両にデフォルト紐付けされた荷物がある場合、その情報を返す
  def assignment_defaults
    {
      product_name: cargo_name,
      cargo_type: cargo_category,
      shipper_id: shipper_id,
      origin_location_id: default_origin_id,
      destination_location_id: default_destination_id
    }.compact
  end
end
