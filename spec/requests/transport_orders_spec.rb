require "rails_helper"

RSpec.describe "TransportOrders", type: :request do
  let(:tenant) do
    Tenant.first || Tenant.create!(name: "Test Tenant")
  end

  let(:employee) do
    ActsAsTenant.with_tenant(tenant) do
      Employee.find_or_create_by!(employee_code: "TEST001") do |e|
        e.last_name = "テスト"
        e.first_name = "太郎"
        e.email = "test.employee@example.com"
      end
    end
  end

  let(:user) do
    ActsAsTenant.with_tenant(tenant) do
      User.find_by(email: "admin@example.com") ||
        User.create!(
          email: "admin@example.com",
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

  describe "GET /transport_orders" do
    it "returns http success" do
      get transport_orders_path
      expect(response).to have_http_status(:success)
    end

    it "shows orders for current month by default" do
      ActsAsTenant.with_tenant(tenant) do
        TransportOrder.create!(order_date: Date.current)
      end
      get transport_orders_path
      expect(response.body).to include("運送明細入力")
    end

    it "filters by date parameter" do
      get transport_orders_path(date: "2025-06-01")
      expect(response).to have_http_status(:success)
      expect(response.body).to include("2025年06月")
    end
  end

  describe "POST /transport_orders/batch_update" do
    it "creates new transport orders" do
      post batch_update_transport_orders_path, params: {
        updates: [
          { order_date: Date.current.to_s, billing_base_amount: 10000 }
        ]
      }, as: :json

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json["success"]).to be true
      expect(json["message"]).to include("1件を更新しました")
    end

    it "updates existing transport orders" do
      order = ActsAsTenant.with_tenant(tenant) do
        TransportOrder.create!(order_date: Date.current, billing_base_amount: 5000)
      end

      post batch_update_transport_orders_path, params: {
        updates: [
          { id: order.id, order_date: Date.current.to_s, billing_base_amount: 15000 }
        ]
      }, as: :json

      expect(response).to have_http_status(:success)
      order.reload
      expect(order.billing_base_amount).to eq(15000)
    end

    it "returns errors for invalid data" do
      post batch_update_transport_orders_path, params: {
        updates: [
          { order_date: nil }
        ]
      }, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      json = JSON.parse(response.body)
      expect(json["success"]).to be false
    end
  end

  describe "GET /transport_orders/:id" do
    it "returns order as JSON" do
      order = ActsAsTenant.with_tenant(tenant) do
        TransportOrder.create!(order_date: Date.current, billing_base_amount: 10000)
      end

      get transport_order_path(order), as: :json
      expect(response).to have_http_status(:success)

      json = JSON.parse(response.body)
      expect(json["billing_base_amount"]).to eq(10000)
    end
  end

  describe "DELETE /transport_orders/:id" do
    it "deletes the transport order" do
      order = ActsAsTenant.with_tenant(tenant) do
        TransportOrder.create!(order_date: Date.current)
      end
      order_id = order.id

      delete transport_order_path(order), as: :json

      expect(response).to have_http_status(:no_content)
      ActsAsTenant.with_tenant(tenant) do
        expect(TransportOrder.find_by(id: order_id)).to be_nil
      end
    end
  end
end
