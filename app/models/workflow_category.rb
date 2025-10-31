class WorkflowCategory < ApplicationRecord
  has_many :stage_templates, -> { order(:position) }, class_name: "WorkflowStageTemplate", dependent: :destroy, inverse_of: :workflow_category
  has_many :notifications, class_name: "WorkflowCategoryNotification", dependent: :destroy, inverse_of: :workflow_category
  has_many :workflow_requests, dependent: :restrict_with_exception

  validates :name, :code, presence: true
  validates :code, uniqueness: true

  scope :active, -> { where(active: true) }

  def default_stage_attributes
    stage_templates.map do |template|
      {
        position: template.position,
        name: template.name,
        responsible_role: template.responsible_role,
        responsible_user_id: template.responsible_user_id
      }
    end
  end

  def notification_roles
    notifications.pluck(:role)
  end
end
