class ApplicationController < ActionController::Base
  include CanCan::ControllerAdditions

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern
  before_action :authenticate_user!
  around_action :scope_current_tenant
  before_action :ensure_tenant_presence!, if: :user_signed_in?
  before_action :set_locale

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
    # Single-tenant mode: always use the configured default tenant
    if Rails.configuration.x.tenancy.single_tenant_mode
      tenant = find_tenant_by_slug(default_tenant_slug)
      tenant ||= first_or_create_development_tenant if Rails.env.development? || Rails.env.test?
      return tenant
    end

    # Multi-tenant mode: tenant is determined by subdomain
    slug = host_tenant_slug

    # No subdomain = no tenant (login page only, no dashboard access)
    return nil if slug.nil? && on_base_domain?

    # Try to find tenant from subdomain or session
    slug ||= tenant_slug_from_session
    tenant = find_tenant_by_slug(slug)

    # Fallback for development/localhost only
    if tenant.nil? && (Rails.env.development? || Rails.env.test?)
      tenant = first_or_create_development_tenant
    end

    tenant
  end

  def on_base_domain?
    host = request.host&.downcase
    base_domain = Rails.configuration.x.tenancy.base_domain&.downcase
    return false if base_domain.blank?

    host == base_domain || host == "www.#{base_domain}"
  end

  def host_tenant_slug
    host = request.host
    return if host.blank?

    normalized_host = host.downcase
    base_domain = Rails.configuration.x.tenancy.base_domain&.downcase

    # Local development: use default tenant
    local_hosts = %w[localhost 127.0.0.1 ::1]
    return default_tenant_slug if local_hosts.include?(normalized_host)

    if base_domain.present?
      # No subdomain (e.g., tms-cloud.jp) -> no tenant (login page only)
      return nil if normalized_host == base_domain
      return nil if normalized_host == "www.#{base_domain}"

      # Subdomain present (e.g., wakatrans.tms-cloud.jp) -> extract tenant slug
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
      tenant = Tenant.unscoped.find_by(slug: default_tenant_slug)
      tenant ||= Tenant.unscoped.first
      tenant ||= create_tenant(default_tenant_slug, "若林運送")
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

  def set_locale
    I18n.locale = :ja
  end
end
