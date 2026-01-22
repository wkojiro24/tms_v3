require "test_helper"

class AuthenticationFlowTest < ActionDispatch::IntegrationTest
  fixtures :tenants, :employees, :users

  setup do
    host! "default.lvh.me"
  end

  test "admin can sign in and sign out without tenant errors" do
    get new_user_session_path
    assert_response :success

    post user_session_path, params: {
      user: {
        email: users(:admin).email,
        password: "password"
      }
    }
    assert_redirected_to root_path

    follow_redirect!
    assert_response :success

    delete destroy_user_session_path
    assert_redirected_to root_path
  end
end
