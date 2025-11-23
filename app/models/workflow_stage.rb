class WorkflowStage < ApplicationRecord
  include TenantScoped

  belongs_to :workflow_request
  belongs_to :responsible_user, class_name: "User", optional: true
  has_many :approvals, class_name: "WorkflowApproval", dependent: :destroy

  STATUSES = %w[pending active approved rejected returned held].freeze

  validates :name, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :position, numericality: { greater_than: 0 }

  scope :ordered, -> { order(:position) }
  scope :active, -> { where(status: "active") }

  def activate!
    update!(status: "active", activated_at: Time.current)
  end

  def complete!(action:, actor:, comment: nil)
    approvals.create!(actor:, action:, comment:, acted_at: Time.current)
    if action == "held"
      update!(last_comment: comment.presence)
    else
      status_value = case action
                     when "approved" then "approved"
                     when "rejected" then "rejected"
                     when "returned" then "returned"
                     else "approved"
                     end
      update!(status: status_value, completed_at: Time.current, last_comment: comment)
    end
  end

  def actionable_by?(user)
    return false unless status == "active"

    if responsible_user.present?
      responsible_user == user
    elsif responsible_role.present?
      user.role == responsible_role
    else
      false
    end
  end

  def responsible_label
    if responsible_user.present?
      responsible_user.display_name
    elsif responsible_role.present?
      responsible_role.humanize
    else
      "担当者未設定"
    end
  end
end
