class WorkflowApproval < ApplicationRecord
  include TenantScoped

  ACTIONS = %w[approved rejected returned held].freeze

  belongs_to :workflow_stage
  belongs_to :actor, class_name: "User"

  validates :action, inclusion: { in: ACTIONS }
  validates :acted_at, presence: true

  delegate :workflow_request, to: :workflow_stage
end
