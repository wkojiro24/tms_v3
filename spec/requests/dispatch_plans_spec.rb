require "rails_helper"

RSpec.describe "DispatchPlans", type: :request do
  let(:tenant) do
    Tenant.first || Tenant.create!(name: "Test Tenant")
  end

  let(:employee) do
    ActsAsTenant.with_tenant(tenant) do
      Employee.find_or_create_by!(employee_code: "TEST001") do |e|
        e.last_name = "テスト"
        e.first_name = "太郎"
        e.email = "test.dispatch@example.com"
      end
    end
  end

  let(:user) do
    ActsAsTenant.with_tenant(tenant) do
      User.find_by(email: "dispatch.admin@example.com") ||
        User.create!(
          email: "dispatch.admin@example.com",
          password: "password123",
          role: :admin,
          employment: employee
        )
    end
  end

  before do
    ActsAsTenant.current_tenant = tenant
    sign_in user
  end

  after do
    ActsAsTenant.current_tenant = nil
  end

  describe "GET /dispatch" do
    it "returns http success" do
      get dispatch_path
      expect(response).to have_http_status(:success)
    end

    it "creates dispatch plan for current date if not exists" do
      get dispatch_path
      expect(response).to have_http_status(:success)
      # 配車計画が作成されていることを確認（レスポンスにステータスが含まれる）
      expect(response.body).to include("下書き")
    end

    it "shows dispatch plan for specified date" do
      get dispatch_path(date: "2026-01-20")
      expect(response).to have_http_status(:success)
      # 日付入力欄に値が設定されていることを確認
      expect(response.body).to include("2026-01-20")
    end
  end

  describe "GET /dispatch_plans" do
    it "returns http success" do
      get dispatch_plans_path
      expect(response).to have_http_status(:success)
    end
  end

  describe "POST /dispatch_plans/batch_update" do
    it "creates new dispatch assignments" do
      vehicle = ActsAsTenant.with_tenant(tenant) do
        Vehicle.first || Vehicle.create!(registration_number: "TEST-V001")
      end

      post batch_update_dispatch_plans_path, params: {
        date: Date.current.to_s,
        assignments: [
          {
            vehicle_id: vehicle.id,
            sequence: 1,
            product_name: "塩酸",
            instruction: "積発"
          }
        ]
      }, as: :json

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json["success"]).to be true
    end

    it "updates existing dispatch assignments" do
      plan = ActsAsTenant.with_tenant(tenant) do
        DispatchPlan.create!(date: Date.current)
      end
      assignment = ActsAsTenant.with_tenant(tenant) do
        plan.dispatch_assignments.create!(sequence: 1, product_name: "塩酸")
      end

      post batch_update_dispatch_plans_path, params: {
        date: Date.current.to_s,
        assignments: [
          {
            id: assignment.id,
            sequence: 1,
            product_name: "苛性ソーダ"
          }
        ]
      }, as: :json

      expect(response).to have_http_status(:success)
      assignment.reload
      expect(assignment.product_name).to eq("苛性ソーダ")
    end
  end

  describe "POST /dispatch_plans/create_assignment" do
    it "creates a new assignment" do
      post create_assignment_dispatch_plans_path, params: {
        date: Date.current.to_s,
        sequence: 1,
        product_name: "塩酸"
      }, as: :json

      expect(response).to have_http_status(:created)
    end
  end

  describe "DELETE /dispatch_plans/destroy_assignment" do
    it "deletes the assignment" do
      plan = ActsAsTenant.with_tenant(tenant) do
        DispatchPlan.create!(date: Date.current)
      end
      assignment = ActsAsTenant.with_tenant(tenant) do
        plan.dispatch_assignments.create!(sequence: 1)
      end

      delete destroy_assignment_dispatch_plans_path, params: {
        assignment_id: assignment.id
      }, as: :json

      expect(response).to have_http_status(:no_content)
      ActsAsTenant.with_tenant(tenant) do
        expect(DispatchAssignment.find_by(id: assignment.id)).to be_nil
      end
    end
  end

  describe "POST /dispatch_plans/confirm" do
    let(:plan) do
      ActsAsTenant.with_tenant(tenant) do
        DispatchPlan.create!(date: Date.current + 30.days)
      end
    end

    it "confirms the dispatch plan" do
      post confirm_dispatch_plans_path, params: {
        date: plan.date.to_s
      }, as: :json

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json["success"]).to be true

      plan.reload
      expect(plan.confirmed?).to be true
    end
  end

  describe "POST /dispatch_plans/unlock" do
    let(:plan) do
      ActsAsTenant.with_tenant(tenant) do
        DispatchPlan.create!(date: Date.current + 31.days, status: :confirmed)
      end
    end

    it "unlocks the confirmed dispatch plan" do
      post unlock_dispatch_plans_path, params: {
        date: plan.date.to_s,
        reason: "修正が必要"
      }, as: :json

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json["success"]).to be true

      plan.reload
      expect(plan.draft?).to be true
    end
  end
end
