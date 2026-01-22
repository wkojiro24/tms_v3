require "rails_helper"

RSpec.describe TransportOrder, type: :model do
  let(:tenant) do
    Tenant.first || Tenant.create!(name: "Test Tenant")
  end

  around do |example|
    ActsAsTenant.with_tenant(tenant) do
      example.run
    end
  end

  describe "validations" do
    it "is valid with order_date" do
      order = TransportOrder.new(order_date: Date.current)
      expect(order).to be_valid
    end

    it "is invalid without order_date" do
      order = TransportOrder.new(order_date: nil)
      expect(order).to be_invalid
      expect(order.errors[:order_date]).to be_present
    end

    it "validates uniqueness of order_no within tenant" do
      TransportOrder.create!(order_date: Date.current, order_no: "ORD-001")
      duplicate = TransportOrder.new(order_date: Date.current, order_no: "ORD-001")
      expect(duplicate).to be_invalid
      expect(duplicate.errors[:order_no]).to be_present
    end

    it "allows blank order_no" do
      order1 = TransportOrder.create!(order_date: Date.current, order_no: nil)
      order2 = TransportOrder.new(order_date: Date.current, order_no: nil)
      expect(order2).to be_valid
    end
  end

  describe "billing_total calculation" do
    it "calculates billing_total before save" do
      order = TransportOrder.new(
        order_date: Date.current,
        billing_base_amount: 10000,
        billing_surcharge: 2000,
        billing_toll: 1500,
        billing_other: 500,
        billing_tax: 1400
      )
      order.save!
      expect(order.billing_total).to eq(15400)
    end

    it "handles nil values in calculation" do
      order = TransportOrder.new(
        order_date: Date.current,
        billing_base_amount: 10000,
        billing_toll: nil
      )
      order.save!
      expect(order.billing_total).to eq(10000)
    end
  end

  describe "scopes" do
    before do
      TransportOrder.create!(order_date: Date.new(2025, 1, 15))
      TransportOrder.create!(order_date: Date.new(2025, 1, 20))
      TransportOrder.create!(order_date: Date.new(2025, 2, 10))
    end

    describe ".by_date_range" do
      it "returns orders within date range" do
        orders = TransportOrder.by_date_range(Date.new(2025, 1, 1), Date.new(2025, 1, 31))
        expect(orders.count).to eq(2)
      end
    end

    describe ".unbilled" do
      it "returns orders without billing_date" do
        TransportOrder.first.update!(billing_date: Date.current)
        expect(TransportOrder.unbilled.count).to eq(2)
      end
    end

    describe ".billed_in" do
      it "returns orders billed in given month" do
        TransportOrder.first.update!(billing_date: Date.new(2025, 1, 25))
        TransportOrder.second.update!(billing_date: Date.new(2025, 2, 5))
        expect(TransportOrder.billed_in("202501").count).to eq(1)
      end
    end
  end

  describe "enum status" do
    it "has draft as default" do
      order = TransportOrder.create!(order_date: Date.current)
      expect(order.draft?).to be true
    end

    it "can change status" do
      order = TransportOrder.create!(order_date: Date.current)
      order.confirmed!
      expect(order.confirmed?).to be true
    end
  end
end
