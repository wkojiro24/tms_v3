class JobCategory < ApplicationRecord
  include TenantScoped

  has_many :employees, dependent: :nullify

  validates :code, presence: true, uniqueness: { scope: :tenant_id }
  validates :name, presence: true

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(:name) }

  def display_name
    name
  end
end
