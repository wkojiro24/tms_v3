class WorkflowNote < ApplicationRecord
  belongs_to :workflow_request
  belongs_to :author, class_name: "User"

  validates :body, presence: true

  delegate :display_name, to: :author, prefix: true
end
