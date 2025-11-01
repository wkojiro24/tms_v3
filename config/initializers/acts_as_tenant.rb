ActsAsTenant.configure do |config|
  config.require_tenant = true
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
