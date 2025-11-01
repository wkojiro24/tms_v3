module TenantScoped
  extend ActiveSupport::Concern

  included do
    acts_as_tenant :tenant
    belongs_to :tenant
  end
end
