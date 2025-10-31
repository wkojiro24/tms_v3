# frozen_string_literal: true

class Ability
  include CanCan::Ability

  def initialize(user)
    user ||= User.new(role: "staff")

    can :read, :dashboard
    can :read, :portal

    if user.admin_role?
      can :manage, :all
      can :access, :admin
    end
  end
end
