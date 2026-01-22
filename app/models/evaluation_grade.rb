class EvaluationGrade < ApplicationRecord
  include TenantScoped

  has_many :employee_reviews, dependent: :nullify

  validates :code, presence: true, uniqueness: { scope: :tenant_id }
  validates :name, presence: true

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(:score, :name) }

  def display_name
    name
  end
end
