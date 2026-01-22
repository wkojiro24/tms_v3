require "rails_helper"

RSpec.describe DispatchAssignment, type: :model do
  let(:tenant) { Tenant.first || Tenant.create!(name: "Test Tenant") }
  let(:dispatch_plan) do
    ActsAsTenant.with_tenant(tenant) do
      DispatchPlan.create!(date: Date.current)
    end
  end

  before do
    ActsAsTenant.current_tenant = tenant
  end

  after do
    ActsAsTenant.current_tenant = nil
  end

  describe "validations" do
    it "is valid with required attributes" do
      assignment = DispatchAssignment.new(
        dispatch_plan: dispatch_plan,
        sequence: 1
      )
      expect(assignment).to be_valid
    end

    it "is invalid without sequence" do
      assignment = DispatchAssignment.new(
        dispatch_plan: dispatch_plan,
        sequence: nil
      )
      expect(assignment).to be_invalid
      expect(assignment.errors[:sequence]).to be_present
    end

    it "requires sequence to be positive" do
      assignment = DispatchAssignment.new(
        dispatch_plan: dispatch_plan,
        sequence: 0
      )
      expect(assignment).to be_invalid
    end
  end

  describe "associations" do
    it "belongs to dispatch_plan" do
      assignment = DispatchAssignment.new(dispatch_plan: dispatch_plan, sequence: 1)
      expect(assignment.dispatch_plan).to eq(dispatch_plan)
    end

    it "optionally belongs to vehicle" do
      assignment = DispatchAssignment.new(dispatch_plan: dispatch_plan, sequence: 1, vehicle: nil)
      expect(assignment).to be_valid
    end

    it "optionally belongs to employee" do
      assignment = DispatchAssignment.new(dispatch_plan: dispatch_plan, sequence: 1, employee: nil)
      expect(assignment).to be_valid
    end
  end

  describe "enum status" do
    it "has pending as default" do
      assignment = DispatchAssignment.create!(dispatch_plan: dispatch_plan, sequence: 1)
      expect(assignment.pending?).to be true
    end

    it "can be in_progress" do
      assignment = DispatchAssignment.create!(dispatch_plan: dispatch_plan, sequence: 1)
      assignment.in_progress!
      expect(assignment.in_progress?).to be true
    end

    it "can be completed" do
      assignment = DispatchAssignment.create!(dispatch_plan: dispatch_plan, sequence: 1)
      assignment.completed!
      expect(assignment.completed?).to be true
    end

    it "can be cancelled" do
      assignment = DispatchAssignment.create!(dispatch_plan: dispatch_plan, sequence: 1)
      assignment.cancelled!
      expect(assignment.cancelled?).to be true
    end
  end

  describe "helper methods" do
    it "#formatted_departure returns time in HH:MM format" do
      assignment = DispatchAssignment.new(
        dispatch_plan: dispatch_plan,
        sequence: 1,
        scheduled_departure: Time.parse("06:30")
      )
      expect(assignment.formatted_departure).to eq("06:30")
    end

    it "#formatted_arrival returns time in HH:MM format" do
      assignment = DispatchAssignment.new(
        dispatch_plan: dispatch_plan,
        sequence: 1,
        scheduled_arrival: Time.parse("10:00")
      )
      expect(assignment.formatted_arrival).to eq("10:00")
    end

    it "#status_label returns Japanese label" do
      assignment = DispatchAssignment.new(dispatch_plan: dispatch_plan, sequence: 1)

      assignment.status = "pending"
      expect(assignment.status_label).to eq("未配車")

      assignment.status = "in_progress"
      expect(assignment.status_label).to eq("配送中")

      assignment.status = "completed"
      expect(assignment.status_label).to eq("完了")

      assignment.status = "cancelled"
      expect(assignment.status_label).to eq("キャンセル")
    end
  end

  describe "scopes" do
    let(:vehicle) do
      ActsAsTenant.with_tenant(tenant) do
        Vehicle.first || Vehicle.create!(registration_number: "TEST-001")
      end
    end

    before do
      DispatchAssignment.create!(dispatch_plan: dispatch_plan, sequence: 1, vehicle: vehicle)
      DispatchAssignment.create!(dispatch_plan: dispatch_plan, sequence: 2, vehicle: vehicle)
      DispatchAssignment.create!(dispatch_plan: dispatch_plan, sequence: 1, vehicle: nil)
    end

    it ".for_vehicle filters by vehicle_id" do
      assignments = DispatchAssignment.for_vehicle(vehicle.id)
      expect(assignments.count).to eq(2)
    end

    it ".ordered sorts by vehicle_id and sequence" do
      assignments = DispatchAssignment.for_vehicle(vehicle.id).ordered
      expect(assignments.first.sequence).to eq(1)
      expect(assignments.last.sequence).to eq(2)
    end
  end

  describe "#anomaly_alerts" do
    let(:vehicle) do
      ActsAsTenant.with_tenant(tenant) do
        Vehicle.create!(registration_number: "ANOMALY-001")
      end
    end

    let(:default_destination) do
      ActsAsTenant.with_tenant(tenant) do
        Destination.create!(code: "D001", name: "デフォルト卸場")
      end
    end

    let(:different_destination) do
      ActsAsTenant.with_tenant(tenant) do
        Destination.create!(code: "D002", name: "別の卸場")
      end
    end

    let(:default_shipper) do
      ActsAsTenant.with_tenant(tenant) do
        Shipper.create!(code: "SHP001", name: "デフォルト荷主")
      end
    end

    let(:different_shipper) do
      ActsAsTenant.with_tenant(tenant) do
        Shipper.create!(code: "SHP002", name: "別の荷主")
      end
    end

    context "when vehicle has no cargo binding" do
      it "returns empty array" do
        assignment = DispatchAssignment.create!(
          dispatch_plan: dispatch_plan,
          vehicle: vehicle,
          sequence: 1,
          destination_location: different_destination
        )
        expect(assignment.anomaly_alerts).to eq([])
      end
    end

    context "when vehicle has cargo binding" do
      let!(:cargo_binding) do
        ActsAsTenant.with_tenant(tenant) do
          VehicleCargoBinding.create!(
            vehicle: vehicle,
            cargo_name: "塩酸",
            is_default: true,
            default_destination: default_destination,
            shipper: default_shipper
          )
        end
      end

      it "returns empty array when destination matches default" do
        assignment = DispatchAssignment.create!(
          dispatch_plan: dispatch_plan,
          vehicle: vehicle,
          sequence: 1,
          destination_location: default_destination
        )
        expect(assignment.anomaly_alerts).to eq([])
      end

      it "returns alert when destination differs from default" do
        assignment = DispatchAssignment.create!(
          dispatch_plan: dispatch_plan,
          vehicle: vehicle,
          sequence: 1,
          destination_location: different_destination
        )

        alerts = assignment.anomaly_alerts
        expect(alerts.length).to eq(1)
        expect(alerts.first[:type]).to eq(:different_destination)
        expect(alerts.first[:message]).to eq("通常と異なる卸場")
        expect(alerts.first[:usual]).to eq("デフォルト卸場")
        expect(alerts.first[:current]).to eq("別の卸場")
      end

      it "returns alert when shipper differs from default" do
        assignment = DispatchAssignment.create!(
          dispatch_plan: dispatch_plan,
          vehicle: vehicle,
          sequence: 1,
          shipper: different_shipper
        )

        alerts = assignment.anomaly_alerts
        shipper_alert = alerts.find { |a| a[:type] == :different_shipper }
        expect(shipper_alert).to be_present
        expect(shipper_alert[:message]).to eq("通常と異なる荷主")
      end

      it "returns alert when product differs from default" do
        assignment = DispatchAssignment.create!(
          dispatch_plan: dispatch_plan,
          vehicle: vehicle,
          sequence: 1,
          product_name: "苛性ソーダ"
        )

        alerts = assignment.anomaly_alerts
        cargo_alert = alerts.find { |a| a[:type] == :different_cargo }
        expect(cargo_alert).to be_present
        expect(cargo_alert[:message]).to eq("通常と異なる荷物")
        expect(cargo_alert[:usual]).to eq("塩酸")
        expect(cargo_alert[:current]).to eq("苛性ソーダ")
      end
    end
  end

  describe "#has_anomaly?" do
    let(:vehicle) do
      ActsAsTenant.with_tenant(tenant) do
        Vehicle.create!(registration_number: "HAS-ANOMALY-001")
      end
    end

    it "returns false when no vehicle assigned" do
      assignment = DispatchAssignment.new(dispatch_plan: dispatch_plan, sequence: 1)
      expect(assignment.has_anomaly?).to be false
    end

    it "returns false when no anomaly alerts" do
      assignment = DispatchAssignment.create!(
        dispatch_plan: dispatch_plan,
        vehicle: vehicle,
        sequence: 1
      )
      expect(assignment.has_anomaly?).to be false
    end

    context "with cargo binding and different destination" do
      let(:default_destination) do
        ActsAsTenant.with_tenant(tenant) do
          Destination.create!(code: "D100", name: "通常卸場")
        end
      end

      let(:other_destination) do
        ActsAsTenant.with_tenant(tenant) do
          Destination.create!(code: "D101", name: "異常卸場")
        end
      end

      let!(:cargo_binding) do
        ActsAsTenant.with_tenant(tenant) do
          VehicleCargoBinding.create!(
            vehicle: vehicle,
            cargo_name: "テスト荷物",
            is_default: true,
            default_destination: default_destination
          )
        end
      end

      it "returns true when has anomaly alerts" do
        assignment = DispatchAssignment.create!(
          dispatch_plan: dispatch_plan,
          vehicle: vehicle,
          sequence: 1,
          destination_location: other_destination
        )
        expect(assignment.has_anomaly?).to be true
      end
    end
  end

  describe "#is_relay?" do
    let(:vehicle) do
      ActsAsTenant.with_tenant(tenant) do
        Vehicle.create!(registration_number: "RELAY-001")
      end
    end

    let(:driver1) do
      ActsAsTenant.with_tenant(tenant) do
        Employee.create!(employee_code: "DRV001", last_name: "田中", first_name: "一郎")
      end
    end

    let(:driver2) do
      ActsAsTenant.with_tenant(tenant) do
        Employee.create!(employee_code: "DRV002", last_name: "佐藤", first_name: "二郎")
      end
    end

    it "returns false when vehicle is not assigned" do
      assignment = DispatchAssignment.new(dispatch_plan: dispatch_plan, sequence: 1)
      expect(assignment.is_relay?).to be false
    end

    it "returns false when only one assignment for vehicle" do
      assignment = DispatchAssignment.create!(
        dispatch_plan: dispatch_plan,
        vehicle: vehicle,
        employee: driver1,
        sequence: 1
      )
      expect(assignment.is_relay?).to be false
    end

    it "returns false when same driver for all assignments" do
      assignment1 = DispatchAssignment.create!(
        dispatch_plan: dispatch_plan,
        vehicle: vehicle,
        employee: driver1,
        sequence: 1
      )
      DispatchAssignment.create!(
        dispatch_plan: dispatch_plan,
        vehicle: vehicle,
        employee: driver1,
        sequence: 2
      )
      expect(assignment1.is_relay?).to be false
    end

    it "returns true when different drivers for same vehicle (乗り回し)" do
      assignment1 = DispatchAssignment.create!(
        dispatch_plan: dispatch_plan,
        vehicle: vehicle,
        employee: driver1,
        sequence: 1
      )
      DispatchAssignment.create!(
        dispatch_plan: dispatch_plan,
        vehicle: vehicle,
        employee: driver2,
        sequence: 2
      )
      expect(assignment1.is_relay?).to be true
    end

    it "returns false when other assignment has no driver" do
      assignment1 = DispatchAssignment.create!(
        dispatch_plan: dispatch_plan,
        vehicle: vehicle,
        employee: driver1,
        sequence: 1
      )
      DispatchAssignment.create!(
        dispatch_plan: dispatch_plan,
        vehicle: vehicle,
        employee: nil,
        sequence: 2
      )
      expect(assignment1.is_relay?).to be false
    end
  end
end
