class VehicleInspectionRecord < ApplicationRecord
  include TenantScoped

  belongs_to :vehicle

  enum status: {
    scheduled: "scheduled",
    completed: "completed",
    overdue: "overdue"
  }, _suffix: true

  validates :inspection_type, presence: true
  validates :status, inclusion: { in: statuses.keys }
  validates :scheduled_on, presence: true

  scope :upcoming, -> { where(status: %w[scheduled overdue]).order(:scheduled_on) }
  scope :recent, -> { order(scheduled_on: :desc) }
end
