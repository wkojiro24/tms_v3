class WorkflowCategoryNotification < ApplicationRecord
  include TenantScoped

  belongs_to :workflow_category

  validates :role, presence: true
end
