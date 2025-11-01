module Admin
  class BaseController < ApplicationController
    before_action :authenticate_user!
    before_action :authorize_admin!
    before_action :ensure_tenant_presence!

    layout "application"

    private

    def authorize_admin!
      authorize! :access, :admin
    end
  end
end
