ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
    setup do
      tenant = Tenant.find_by(slug: "default")

      unless tenant
        tenant = Tenant.create!(slug: "default", name: "Default Tenant", time_zone: "Asia/Tokyo")
      end

      ActsAsTenant.current_tenant = tenant
      Current.tenant = tenant
    end

    teardown do
      ActsAsTenant.current_tenant = nil
      Current.reset
    end
  end
end
