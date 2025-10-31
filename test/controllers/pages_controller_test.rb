require "test_helper"

class PagesControllerTest < ActionDispatch::IntegrationTest
  test "should get announcements" do
    get pages_announcements_url
    assert_response :success
  end

  test "should get revenue" do
    get pages_revenue_url
    assert_response :success
  end

  test "should get dispatch" do
    get pages_dispatch_url
    assert_response :success
  end

  test "should get fleet" do
    get pages_fleet_url
    assert_response :success
  end

  test "should get hr" do
    get pages_hr_url
    assert_response :success
  end

  test "should get knowledge" do
    get pages_knowledge_url
    assert_response :success
  end

  test "should get workflow" do
    get pages_workflow_url
    assert_response :success
  end

  test "should get faq" do
    get pages_faq_url
    assert_response :success
  end

  test "should get admin" do
    get pages_admin_url
    assert_response :success
  end
end
