module Admin
  class BaseController < ApplicationController
    before_action :authenticate_user!
    before_action :require_admin!
    before_action :ensure_tenant_presence!

    private

    def ensure_tenant_presence!
      return if ActsAsTenant.current_tenant

      tenant = Tenant.first
      ActsAsTenant.current_tenant = tenant if tenant
    end

    def require_admin!
      return if current_user && admin_user?(current_user)

      redirect_to root_path, alert: "権限がありません。"
    end

    def admin_user?(user)
      return user.admin? if user.respond_to?(:admin?)
      return true if user.respond_to?(:role) && user.role.to_s == "admin"

      false
    end
  end
end
