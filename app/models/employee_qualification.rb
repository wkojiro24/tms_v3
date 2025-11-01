class EmployeeQualification < ApplicationRecord
  include TenantScoped

  belongs_to :employee

  validates :name, presence: true
end
