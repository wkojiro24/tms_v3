# frozen_string_literal: true

class Ability
  include CanCan::Ability

  def initialize(user)
    user ||= User.new(role: "staff")

    can :read, :dashboard
    can :read, :portal

    if user.can_submit_workflow_requests?
      can :create, WorkflowRequest
      can :submit, WorkflowRequest, requester_id: user.id
    else
      cannot :create, WorkflowRequest
      cannot :submit, WorkflowRequest
    end

    can :read, WorkflowRequest, requester_id: user.id
    can :update, WorkflowRequest, requester_id: user.id, status: %w[draft returned]

    can :read, WorkflowStage do |stage|
      stage.workflow_request.requester_id == user.id
    end

    if user.admin_role?
      can :manage, :all
      can :access, :admin
    else
      can :review, WorkflowStage do |stage|
        stage.actionable_by?(user)
      end
      can :act, WorkflowStage do |stage|
        stage.actionable_by?(user)
      end
    end
  end
end
