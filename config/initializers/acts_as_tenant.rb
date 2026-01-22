ActsAsTenant.configure do |config|
  # Set to false to allow Devise/Warden to deserialize users from session
  # before the tenant context is established. Tenant enforcement is handled
  # at the controller level via ensure_tenant_presence!
  config.require_tenant = false
end

Warden::Manager.after_set_user do |user, auth, opts|
  next unless user.is_a?(User)

  slug = user.tenant&.slug
  next if slug.blank?

  auth.session(opts[:scope])["tenant_slug"] = slug
  auth.raw_session["tenant_slug"] = slug if auth.raw_session
end

Warden::Manager.before_logout do |_user, auth, opts|
  auth.session(opts[:scope]).delete("tenant_slug")
  auth.raw_session.delete("tenant_slug") if auth.raw_session
  ActsAsTenant.current_tenant = nil
end
