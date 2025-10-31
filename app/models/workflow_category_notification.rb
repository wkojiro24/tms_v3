class WorkflowCategoryNotification < ApplicationRecord
  belongs_to :workflow_category

  validates :role, presence: true
end
