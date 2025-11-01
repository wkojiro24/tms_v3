class EmployeeAssignment < ApplicationRecord
  include TenantScoped

  belongs_to :employee

  validates :effective_from, presence: true

  scope :current, ->(date = Date.today) {
    where("effective_from <= ? AND (effective_to IS NULL OR effective_to > ?)", date, date)
      .order(effective_from: :desc)
  }

  scope :recent_first, -> { order(effective_from: :desc) }
end
