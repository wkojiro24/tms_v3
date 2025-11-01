class EmployeeReview < ApplicationRecord
  include TenantScoped

  belongs_to :employee

  validates :reviewed_on, presence: true

  scope :recent_first, -> { order(reviewed_on: :desc) }
end
