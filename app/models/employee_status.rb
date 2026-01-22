class EmployeeStatus < ApplicationRecord
  include TenantScoped

  belongs_to :employee

  enum status: {
    active: "active",
    on_leave: "on_leave",
    retired: "retired",
    terminated: "terminated"
  }, _suffix: true

  validates :status, presence: true
  validates :effective_from, presence: true

  scope :current, ->(date = Date.today) {
    where("effective_from <= ? AND (effective_to IS NULL OR effective_to > ?)", date, date)
      .order(effective_from: :desc)
  }

  scope :recent_first, -> { order(effective_from: :desc) }
end
