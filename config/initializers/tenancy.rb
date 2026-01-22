# Multi-tenant configuration
# Tenant is resolved from subdomain (e.g., wakatrans.tms-cloud.jp -> wakatrans tenant)
Rails.application.configure do
  config.x.tenancy = ActiveSupport::OrderedOptions.new unless config.x.respond_to?(:tenancy)

  # Default tenant when no subdomain is present
  config.x.tenancy.default_tenant_slug = "wakatrans"

  # Base domain for subdomain-based tenant resolution
  # e.g., wakatrans.tms-cloud.jp -> tenant slug = "wakatrans"
  config.x.tenancy.base_domain = ENV.fetch("BASE_DOMAIN", "tms-cloud.jp")
  config.x.tenancy.tld_length = 1  # .jp = 1 TLD segment
  config.x.tenancy.single_tenant_mode = false
end
