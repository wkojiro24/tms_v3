require "rails_helper"

RSpec.describe DispatchPlan, type: :model do
  let(:tenant) { Tenant.first || Tenant.create!(name: "Test Tenant") }

  before do
    ActsAsTenant.current_tenant = tenant
  end

  after do
    ActsAsTenant.current_tenant = nil
  end

  describe "validations" do
    it "is valid with date" do
      plan = DispatchPlan.new(date: Date.current)
      expect(plan).to be_valid
    end

    it "is invalid without date" do
      plan = DispatchPlan.new(date: nil)
      expect(plan).to be_invalid
      expect(plan.errors[:date]).to be_present
    end

    it "validates uniqueness of date within tenant" do
      DispatchPlan.create!(date: Date.current)
      duplicate = DispatchPlan.new(date: Date.current)
      expect(duplicate).to be_invalid
      expect(duplicate.errors[:date]).to be_present
    end
  end

  describe "associations" do
    it "has many dispatch_assignments" do
      plan = DispatchPlan.create!(date: Date.current)
      expect(plan).to respond_to(:dispatch_assignments)
    end

    it "destroys associated assignments when destroyed" do
      plan = DispatchPlan.create!(date: Date.current)
      plan.dispatch_assignments.create!(sequence: 1)

      expect { plan.destroy }.to change(DispatchAssignment, :count).by(-1)
    end
  end

  describe "enum status" do
    it "has draft as default" do
      plan = DispatchPlan.create!(date: Date.current)
      expect(plan.draft?).to be true
    end

    it "can be confirmed" do
      plan = DispatchPlan.create!(date: Date.current)
      plan.confirmed!
      expect(plan.confirmed?).to be true
    end

    it "can be completed" do
      plan = DispatchPlan.create!(date: Date.current)
      plan.completed!
      expect(plan.completed?).to be true
    end
  end

  describe ".find_or_create_for_date" do
    it "creates a new plan if not exists" do
      date = Date.current + 10.days
      expect {
        DispatchPlan.find_or_create_for_date(date)
      }.to change(DispatchPlan, :count).by(1)
    end

    it "returns existing plan if exists" do
      date = Date.current + 11.days
      existing = DispatchPlan.create!(date: date)

      result = DispatchPlan.find_or_create_for_date(date)
      expect(result.id).to eq(existing.id)
    end
  end

  describe "scopes" do
    before do
      DispatchPlan.create!(date: Date.new(2026, 1, 15))
      DispatchPlan.create!(date: Date.new(2026, 1, 20))
      DispatchPlan.create!(date: Date.new(2026, 2, 5))
    end

    it ".for_date returns plan for specific date" do
      plans = DispatchPlan.for_date(Date.new(2026, 1, 15))
      expect(plans.count).to eq(1)
    end

    it ".for_month returns plans for the month" do
      plans = DispatchPlan.for_month(Date.new(2026, 1, 1))
      expect(plans.count).to eq(2)
    end
  end
end
