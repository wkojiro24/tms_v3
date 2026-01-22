class DispatchAssignment < ApplicationRecord
  include TenantScoped

  belongs_to :dispatch_plan
  belongs_to :vehicle, optional: true
  belongs_to :employee, optional: true
  belongs_to :shipper, optional: true
  belongs_to :origin_location, class_name: "Destination", optional: true
  belongs_to :destination_location, class_name: "Destination", optional: true
  belongs_to :transport_order, optional: true

  enum :status, { pending: 0, in_progress: 1, completed: 2, cancelled: 3 }

  validates :sequence, presence: true, numericality: { greater_than: 0 }

  scope :for_vehicle, ->(vehicle_id) { where(vehicle_id: vehicle_id) }
  scope :ordered, -> { order(:vehicle_id, :sequence) }

  # 時間フォーマット用ヘルパー
  def formatted_departure
    scheduled_departure&.strftime("%H:%M")
  end

  def formatted_arrival
    scheduled_arrival&.strftime("%H:%M")
  end

  # 納品先名（省略表示）
  def destination_name
    destination_location&.name || destination_location&.code
  end

  # ステータスラベル
  def status_label
    case status
    when "pending" then "未配車"
    when "in_progress" then "配送中"
    when "completed" then "完了"
    when "cancelled" then "キャンセル"
    end
  end

  # 「いつもと違う」アラート情報を返す
  def anomaly_alerts
    return [] unless vehicle_id.present?

    alerts = []
    binding = VehicleCargoBinding.default_for_vehicle(vehicle)

    if binding.present?
      # いつもと違う卸場
      if destination_location_id.present? && binding.default_destination_id.present?
        if destination_location_id != binding.default_destination_id
          alerts << {
            type: :different_destination,
            message: "通常と異なる卸場",
            usual: binding.default_destination&.name,
            current: destination_location&.name
          }
        end
      end

      # いつもと違う積み場
      if origin_location_id.present? && binding.default_origin_id.present?
        if origin_location_id != binding.default_origin_id
          alerts << {
            type: :different_origin,
            message: "通常と異なる積み場",
            usual: binding.default_origin&.name,
            current: origin_location&.name
          }
        end
      end

      # いつもと違う荷物
      if product_name.present? && binding.cargo_name.present?
        if product_name != binding.cargo_name
          alerts << {
            type: :different_cargo,
            message: "通常と異なる荷物",
            usual: binding.cargo_name,
            current: product_name
          }
        end
      end

      # いつもと違う荷主
      if shipper_id.present? && binding.shipper_id.present?
        if shipper_id != binding.shipper_id
          alerts << {
            type: :different_shipper,
            message: "通常と異なる荷主",
            usual: binding.shipper&.name,
            current: shipper&.name
          }
        end
      end
    end

    alerts
  end

  # いつもと違う配車かどうか
  def has_anomaly?
    anomaly_alerts.any?
  end

  # 乗り回し（同じ車両で別のドライバー）を検知
  def is_relay?
    return false unless vehicle_id.present? && dispatch_plan_id.present?

    other_assignments = dispatch_plan.dispatch_assignments
                                     .where(vehicle_id: vehicle_id)
                                     .where.not(id: id)
                                     .where.not(employee_id: [nil, employee_id])
    other_assignments.any?
  end
end
