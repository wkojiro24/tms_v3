require "test_helper"

class AdminMasterManagementTest < ActionDispatch::IntegrationTest
  fixtures :tenants, :employees, :users, :departments, :job_categories, :job_positions, :grade_levels

  setup do
    host! "default.lvh.me"
    @admin = users(:admin)
    sign_in_as(@admin)
  end

  test "can access payroll index with seeded periods" do
    get admin_payrolls_path
    assert_response :success
    assert_match "給与グリッド", response.body
  end

  test "can manage department master" do
    get admin_departments_path
    assert_response :success

    post admin_departments_path, params: { department: { code: "TEST", name: "テスト部署", active: true } }
    follow_redirect!
    assert_response :success
    assert_match "部署を登録しました", response.body
  end

  test "can create employee with master selections" do
    get new_admin_employee_path
    assert_response :success

    assert_difference -> { Employee.count }, 1 do
      post admin_employees_path, params: {
        employee: {
          employee_code: "EMP-999",
          last_name: "試験",
          first_name: "太郎",
          hire_date: "2024-04-01",
          current_status: "active",
          submit_enabled: true,
          department_id: departments(:default_hq).id,
          job_category_id: job_categories(:office).id,
          job_position_id: job_positions(:manager).id,
          grade_level_id: grade_levels(:office_band).id
        }
      }
    end

    follow_redirect!
    assert_response :success
    assert_match "従業員情報を更新しました", response.body unless response.body.include?("従業員を登録しました。")
  end

  private

  def sign_in_as(user, password: "password")
    post user_session_path, params: { user: { email: user.email, password: password } }
    follow_redirect!
    assert_response :success
  end
end
