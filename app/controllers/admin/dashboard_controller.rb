module Admin
  class DashboardController < BaseController
    authorize_resource class: false

    def index
      @recent_users = User.order(created_at: :desc).limit(5)
    end
  end
end
