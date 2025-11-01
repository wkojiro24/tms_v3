class ApplicationController < ActionController::Base
  include CanCan::ControllerAdditions

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern
  around_action :scope_current_tenant
  before_action :ensure_tenant_presence!, if: :user_signed_in?

  rescue_from CanCan::AccessDenied do |_exception|
    redirect_to root_path, alert: "権限がありません。"
  end

  def current_ability
    @current_ability ||= Ability.new(current_user)
  end

  def current_tenant
    Current.tenant
  end
  helper_method :current_tenant

  private

  def scope_current_tenant
    tenant = resolve_current_tenant

    if tenant.present?
      ActsAsTenant.with_tenant(tenant) do
        Current.set(user: current_user, tenant:) { yield }
      end
    else
      ActsAsTenant.without_tenant do
        Current.set(user: current_user, tenant: nil) { yield }
      end
    end
  end

  def ensure_tenant_presence!
    return if current_tenant.present?
    return unless user_signed_in?

    sign_out(current_user)
    redirect_to new_user_session_path, alert: "テナントが見つかりません。もう一度ログインしてください。"
  end

  def resolve_current_tenant
    slug = host_tenant_slug
    slug ||= tenant_slug_from_session
    tenant = find_tenant_by_slug(slug)
    tenant ||= current_user&.tenant
    tenant ||= tenant_from_configuration
    tenant ||= first_or_create_development_tenant if Rails.env.development? || Rails.env.test?
    tenant ||= find_tenant_by_slug(default_tenant_slug)
    tenant
  end

  def host_tenant_slug
    host = request.host
    return if host.blank?

    normalized_host = host.downcase
    base_domain = Rails.configuration.x.tenancy.base_domain&.downcase

    local_hosts = %w[localhost 127.0.0.1 ::1]
    return default_tenant_slug if local_hosts.include?(normalized_host)

    if base_domain.present?
      return default_tenant_slug if normalized_host == base_domain
      if normalized_host.end_with?(".#{base_domain}")
        return normalized_host.delete_suffix(".#{base_domain}")
      end
    end

    tld_length = Rails.configuration.x.tenancy.tld_length || 1
    request.subdomains(tld_length).first
  end

  def tenant_from_configuration
    slug = Rails.configuration.x.tenancy.default_tenant_slug
    return if slug.blank?

    tenant = find_tenant_by_slug(slug)
    return tenant if tenant.present?

    create_tenant(slug, slug.titleize) if Rails.env.development? || Rails.env.test?
  end

  def first_or_create_development_tenant
    ActsAsTenant.without_tenant do
      tenant = Tenant.unscoped.first
      tenant ||= create_tenant(default_tenant_slug, "Default Tenant")
      tenant
    end
  end

  def find_tenant_by_slug(slug)
    return if slug.blank?

    ActsAsTenant.without_tenant do
      tenant = Tenant.unscoped.find_by(slug:)
      tenant&.tap { |t| t.update!(deleted_at: nil) if t.deleted_at? }
    end
  end

  def default_tenant_slug
    Rails.configuration.x.tenancy.default_tenant_slug.presence || "default"
  end

  def create_tenant(slug, name)
    ActsAsTenant.without_tenant do
      Tenant.unscoped.create!(slug:, name:, time_zone: "Asia/Tokyo")
    end
  end

  def tenant_slug_from_session
    session[:tenant_slug]
  end
end
