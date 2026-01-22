require "rails_helper"

RSpec.describe VehicleInspectionSchedule do
  let(:today) { Date.new(2024, 1, 15) }
  let(:tenant) { Tenant.create!(name: "Test Tenant", slug: "test-tenant") }

  around do |example|
    ActsAsTenant.with_tenant(tenant) do
      example.run
    end
  end

  describe "#events" do
    it "builds shaken and periodic events based on first registration date" do
      vehicle = Vehicle.new(first_registration_on: Date.new(2022, 1, 1), gross_weight_kg: 12000)
      events = described_class.new(vehicle: vehicle, today: today).events

      shaken = events.find { |event| event[:label] == "車検" }
      periodic = events.find { |event| event[:label].include?("定期点検") }

      expect(shaken).to be_present
      expect(shaken[:next_due_on]).to eq(Date.new(2025, 1, 1))
      expect(shaken[:previous_due_on]).to eq(Date.new(2024, 1, 1))
      expect(shaken[:days_remaining]).to eq((Date.new(2025, 1, 1) - today).to_i)

      expect(periodic).to be_present
      expect(periodic[:next_due_on]).to eq(Date.new(2025, 1, 1))
      expect(periodic[:interval_months]).to eq(12)
    end

    it "includes tank inspection events when tank manufacture date exists" do
      vehicle = Vehicle.new(first_registration_on: Date.new(2023, 6, 1), tank_made_on: Date.new(2020, 6, 1))
      events = described_class.new(vehicle: vehicle, today: today).events

      tank = events.find { |event| event[:label] == "タンク再検" }
      expect(tank).to be_present
      expect(tank[:next_due_on]).to eq(Date.new(2025, 6, 1))
      expect(tank[:interval_months]).to eq(60)
    end

    it "returns an empty list when no schedule information is available" do
      vehicle = Vehicle.new
      events = described_class.new(vehicle: vehicle, today: today).events

      expect(events).to be_empty
    end
  end
end
