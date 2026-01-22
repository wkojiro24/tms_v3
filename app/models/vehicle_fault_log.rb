class VehicleFaultLog < ApplicationRecord
  include TenantScoped

  belongs_to :vehicle
  has_many_attached :photos

  enum status: {
    on_hold: "on_hold",
    estimating: "estimating",
    repair_ordered: "repair_ordered",
    other: "other"
  }, _suffix: true

  enum severity: {
    low: "low",
    medium: "medium",
    high: "high"
  }, _suffix: true

  validates :title, presence: true
  validates :status, inclusion: { in: statuses.keys }
  validates :severity, inclusion: { in: severities.keys }
  validates :occurred_on, presence: true
  validate :photos_within_limit

  private

  def photos_within_limit
    return unless photos.attachments.size > 10

    errors.add(:photos, "は10枚までアップロードできます。")
  end
end
