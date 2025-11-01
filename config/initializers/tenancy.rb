Rails.application.configure do
  config.x.tenancy = ActiveSupport::OrderedOptions.new unless config.x.respond_to?(:tenancy)

  config.x.tenancy.default_tenant_slug =
    ENV["DEFAULT_TENANT_SLUG"].presence ||
    (Rails.env.development? || Rails.env.test? ? "default" : nil)

  config.x.tenancy.base_domain =
    ENV["TENANT_BASE_DOMAIN"].presence ||
    (Rails.env.development? || Rails.env.test? ? "lvh.me" : nil)

  config.x.tenancy.tld_length =
    ENV["TENANT_TLD_LENGTH"].presence&.to_i ||
    (Rails.env.development? || Rails.env.test? ? 1 : nil)

  if config.x.tenancy.tld_length.present?
    config.action_dispatch.tld_length = config.x.tenancy.tld_length
  end
end
