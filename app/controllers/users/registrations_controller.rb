module Users
  class RegistrationsController < Devise::RegistrationsController
    before_action :configure_sign_up_params, only: [:create]
    before_action :configure_account_update_params, only: [:update]

    private

    def configure_sign_up_params
      devise_parameter_sanitizer.permit(:sign_up, keys: [:tenant_name])
    end

    def configure_account_update_params
      devise_parameter_sanitizer.permit(:account_update, keys: [])
    end

    def build_resource(hash = {})
      super
      assign_tenant_to_resource
      assign_employment_to_resource
    end

    def assign_tenant_to_resource
      return if resource.tenant.present?

      if current_tenant.present?
        resource.tenant = current_tenant
      else
        tenant_name = params.dig(resource_name, :tenant_name).to_s.strip
        resource.tenant_name = tenant_name
        if tenant_name.blank?
          resource.errors.add(:base, "会社名を入力してください。")
        else
          resource.tenant = Tenant.new(name: tenant_name)
        end
      end
    end

    def assign_employment_to_resource
      return if resource.employment.present?

      tenant = resource.tenant || current_tenant
      return if tenant.blank?

      resource.employment = Employee.new(
        tenant: tenant,
        employee_code: generate_employee_code(tenant, resource.email),
        last_name: params.dig(resource_name, :tenant_name).presence || tenant.name,
        first_name: "代表者",
        email: resource.email,
        current_status: "active",
        hire_date: Date.current,
        submit_enabled: true
      )
    end

    def generate_employee_code(tenant, email)
      base = email.to_s.split("@").first.to_s.gsub(/[^a-zA-Z0-9]/, "").upcase
      base = "OWNER" if base.blank?

      candidate = base
      suffix = 1

      while tenant.employees.where(employee_code: candidate).exists?
        candidate = "#{base}-#{format('%02d', suffix)}"
        suffix += 1
      end

      candidate
    end
  end
end
