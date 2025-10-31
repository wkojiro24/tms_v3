class WorkflowStageTemplate < ApplicationRecord
  belongs_to :workflow_category
  belongs_to :responsible_user, class_name: "User", optional: true

  validates :name, presence: true
  validates :position, numericality: { greater_than: 0 }

  def label
    responsible_user&.display_name || responsible_role&.humanize || name
  end
end
