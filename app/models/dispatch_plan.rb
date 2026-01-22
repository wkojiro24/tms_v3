class DispatchPlan < ApplicationRecord
  include TenantScoped

  has_many :dispatch_assignments, dependent: :destroy

  enum :status, { draft: 0, confirmed: 1, completed: 2 }

  validates :date, presence: true
  validates :date, uniqueness: { scope: :tenant_id }

  scope :for_date, ->(date) { where(date: date) }
  scope :for_month, ->(date) {
    where(date: date.beginning_of_month..date.end_of_month)
  }

  def self.find_or_create_for_date(date)
    find_by(date: date) || create!(date: date)
  end
end
