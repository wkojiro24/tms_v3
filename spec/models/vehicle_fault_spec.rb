# spec/models/vehicle_fault_spec.rb
require "rails_helper"

RSpec.describe VehicleFault, type: :model do
  #
  # ActsAsTenant 用に、全テストをテナント付きで実行する
  #
  let(:tenant) do
    # すでに seed 済みなら Tenant.first でOK
    Tenant.first || Tenant.create!(name: "Test Tenant")
  end

  around do |example|
    ActsAsTenant.with_tenant(tenant) do
      example.run
    end
  end

  #
  # テスト用の Vehicle
  #
  let(:vehicle) do
    Vehicle.create!(
      call_sign: "TEST-001",
      registration_number: "テスト800か1234",
      fault_status: :normal
    )
  end

  describe "basic attributes" do
    it "valid_with started_on and summary" do
      fault = VehicleFault.new(
        vehicle: vehicle,
        started_on: Date.today,
        summary: "右前エアサスからエア漏れ"
      )

      expect(fault).to be_valid
    end

    it "is invalid without started_on" do
      fault = VehicleFault.new(
        vehicle: vehicle,
        started_on: nil,
        summary: "テスト故障"
      )

      expect(fault).to be_invalid
    end

    it "is invalid without summary" do
      fault = VehicleFault.new(
        vehicle: vehicle,
        started_on: Date.today,
        summary: nil
      )

      expect(fault).to be_invalid
    end
  end

  describe "fault_status sync with vehicle" do
    it "marks vehicle as faulted when a new unresolved fault is created" do
      expect(vehicle.fault_status).to eq("normal")

      VehicleFault.create!(
        vehicle: vehicle,
        started_on: Date.today,
        summary: "テスト故障1" # resolved_on は nil
      )

      vehicle.reload
      expect(vehicle.fault_status).to eq("faulted")
    end

    it "keeps vehicle faulted while at least one unresolved fault exists" do
      VehicleFault.create!(
        vehicle: vehicle,
        started_on: Date.yesterday,
        summary: "古い故障"
      )

      fault2 = VehicleFault.create!(
        vehicle: vehicle,
        started_on: Date.today,
        summary: "新しい故障"
      )

      vehicle.reload
      expect(vehicle.fault_status).to eq("faulted")

      fault2.update!(resolved_on: Date.today)
      vehicle.reload
      expect(vehicle.fault_status).to eq("faulted")
    end

    it "returns vehicle to normal when all faults are resolved" do
      fault1 = VehicleFault.create!(
        vehicle: vehicle,
        started_on: Date.yesterday,
        summary: "古い故障"
      )

      fault2 = VehicleFault.create!(
        vehicle: vehicle,
        started_on: Date.today,
        summary: "新しい故障"
      )

      vehicle.reload
      expect(vehicle.fault_status).to eq("faulted")

      fault1.update!(resolved_on: Date.today)
      fault2.update!(resolved_on: Date.today)

      vehicle.reload
      expect(vehicle.fault_status).to eq("normal")
    end
  end
end
