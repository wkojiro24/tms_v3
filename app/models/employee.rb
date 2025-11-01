class Employee < ApplicationRecord
  include TenantScoped

  has_one :user, dependent: :nullify, foreign_key: :employment_id, inverse_of: :employment
  has_many :assignments, class_name: "EmployeeAssignment", dependent: :destroy
  has_many :positions, class_name: "EmployeePosition", dependent: :destroy
  has_many :statuses, class_name: "EmployeeStatus", dependent: :destroy
  has_many :qualifications, class_name: "EmployeeQualification", dependent: :destroy
  has_many :reviews, class_name: "EmployeeReview", dependent: :destroy
  has_many :payroll_cells, dependent: :destroy
  has_many :payroll_column_orders, dependent: :destroy

  validates :employee_code, presence: true, uniqueness: { scope: :tenant_id }
  validates :current_status, presence: true

  before_validation :populate_full_name

  scope :ordered_by_code, -> { order(:employee_code) }
  scope :without_user, -> { left_outer_joins(:user).where(users: { id: nil }) }
  scope :submitters, -> { where(submit_enabled: true) }

  def display_label
    [employee_code, full_name.presence || [last_name, first_name].compact.join(" ")].compact.join(" ")
  end

  private

  def populate_full_name
    return if full_name.present?

    self.full_name = [last_name, first_name].compact.join(" ").presence
  end
end
