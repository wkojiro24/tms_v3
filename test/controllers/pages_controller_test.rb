require "test_helper"

class PagesControllerTest < ActionDispatch::IntegrationTest
  test "should get announcements" do
    get announcements_path
    assert_response :success
  end

  test "should get revenue" do
    get revenue_path
    assert_response :success
  end

  test "should get dispatch" do
    get dispatch_path
    assert_response :success
  end

  test "should get fleet" do
    get fleet_path
    assert_response :success
  end

  test "should get hr" do
    get hr_path
    assert_response :success
  end

  test "should get knowledge" do
    get knowledge_path
    assert_response :success
  end

  test "should get workflow" do
    get workflow_path
    assert_redirected_to workflow_requests_path
  end

  test "should get faq" do
    get faq_path
    assert_response :success
  end

  test "should get admin" do
    get admin_path
    assert_response :success
  end
end
