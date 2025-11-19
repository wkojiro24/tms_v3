class VehicleStatus < ApplicationRecord
  include TenantScoped

  STATUSES = {
    active: "active",
    maintenance: "maintenance",
    inspection: "inspection",
    attention: "attention",
    out_of_service: "out_of_service"
  }.freeze

  belongs_to :vehicle
  belongs_to :source, polymorphic: true, optional: true

  validates :status, inclusion: { in: STATUSES.values }
  validates :effective_on, presence: true

  scope :recent_first, -> { order(effective_on: :desc, created_at: :desc) }

  def label
    case status
    when "maintenance" then "整備中"
    when "inspection" then "点検予定"
    when "attention" then "注意"
    when "out_of_service" then "休車"
    else
      "稼働中"
    end
  end
end
