module Users
  class SessionsController < Devise::SessionsController
    private

    # Devise calls this before destroying the session. It fetches the user from
    # Warden, which in turn hits the default scope on User. Wrap the call in
    # without_tenant so ActsAsTenant does not raise when the tenant context
    # has already been cleared.
    def verify_signed_out_user
      ActsAsTenant.without_tenant { super }
    end
  end
end
