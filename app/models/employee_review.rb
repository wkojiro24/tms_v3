class EmployeeReview < ApplicationRecord
  include TenantScoped

  belongs_to :employee
  belongs_to :evaluation_cycle, optional: true
  belongs_to :grade_level, optional: true
  belongs_to :evaluation_grade, optional: true

  validates :reviewed_on, presence: true

  scope :recent_first, -> { order(reviewed_on: :desc) }
end
