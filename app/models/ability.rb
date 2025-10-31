# frozen_string_literal: true

class Ability
  include CanCan::Ability

  def initialize(user)
    user ||= User.new(role: "staff")

    can :read, :dashboard
    can :read, :portal

    can :create, WorkflowRequest
    can :read, WorkflowRequest, requester_id: user.id
    can :update, WorkflowRequest, requester_id: user.id, status: %w[draft returned]
    can :submit, WorkflowRequest, requester_id: user.id

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
