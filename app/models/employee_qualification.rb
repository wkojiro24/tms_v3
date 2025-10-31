class EmployeeQualification < ApplicationRecord
  belongs_to :employee

  validates :name, presence: true
end
