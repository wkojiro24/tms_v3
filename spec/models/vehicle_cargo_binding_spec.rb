require "rails_helper"

RSpec.describe VehicleCargoBinding, type: :model do
  let(:tenant) { Tenant.first || Tenant.create!(name: "Test Tenant") }
  let(:vehicle) { Vehicle.create!(tenant: tenant, registration_number: "東京100あ1234") }

  before do
    ActsAsTenant.current_tenant = tenant
  end

  describe "validations" do
    it "requires cargo_name" do
      binding = VehicleCargoBinding.new(vehicle: vehicle)
      expect(binding).not_to be_valid
      expect(binding.errors[:cargo_name]).to be_present
    end

    it "requires vehicle" do
      binding = VehicleCargoBinding.new(cargo_name: "苛性ソーダ")
      expect(binding).not_to be_valid
    end

    it "prevents duplicate vehicle-cargo combinations" do
      VehicleCargoBinding.create!(vehicle: vehicle, cargo_name: "苛性ソーダ")
      duplicate = VehicleCargoBinding.new(vehicle: vehicle, cargo_name: "苛性ソーダ")
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:vehicle_id]).to include("は既にこの荷物に紐付けられています")
    end

    it "allows same cargo_name for different vehicles" do
      VehicleCargoBinding.create!(vehicle: vehicle, cargo_name: "苛性ソーダ")
      other_vehicle = Vehicle.create!(tenant: tenant, registration_number: "東京200い5678")
      other_binding = VehicleCargoBinding.new(vehicle: other_vehicle, cargo_name: "苛性ソーダ")
      expect(other_binding).to be_valid
    end
  end

  describe "scopes" do
    let!(:default_binding) { VehicleCargoBinding.create!(vehicle: vehicle, cargo_name: "苛性ソーダ", is_default: true, cargo_category: "液体") }
    let!(:other_binding) { VehicleCargoBinding.create!(vehicle: vehicle, cargo_name: "塩酸", is_default: false, cargo_category: "液体") }

    it "filters by default_bindings" do
      expect(VehicleCargoBinding.default_bindings).to include(default_binding)
      expect(VehicleCargoBinding.default_bindings).not_to include(other_binding)
    end

    it "filters by category" do
      expect(VehicleCargoBinding.by_category("液体")).to include(default_binding, other_binding)
    end

    it "filters by vehicle" do
      expect(VehicleCargoBinding.for_vehicle(vehicle)).to include(default_binding, other_binding)
    end
  end

  describe ".default_for_vehicle" do
    let!(:default_binding) { VehicleCargoBinding.create!(vehicle: vehicle, cargo_name: "苛性ソーダ", is_default: true, priority: 0) }
    let!(:secondary_binding) { VehicleCargoBinding.create!(vehicle: vehicle, cargo_name: "塩酸", is_default: true, priority: 1) }

    it "returns the binding with highest priority" do
      expect(VehicleCargoBinding.default_for_vehicle(vehicle)).to eq(default_binding)
    end
  end

  describe "#assignment_defaults" do
    let(:shipper) { Shipper.create!(tenant: tenant, code: "SHP001", name: "Test Shipper") }
    let(:origin) { Destination.create!(tenant: tenant, code: "ORIG01", name: "Origin") }
    let(:destination) { Destination.create!(tenant: tenant, code: "DEST01", name: "Destination") }

    it "returns defaults for assignment" do
      binding = VehicleCargoBinding.create!(
        vehicle: vehicle,
        cargo_name: "苛性ソーダ",
        cargo_category: "液体",
        shipper: shipper,
        default_origin: origin,
        default_destination: destination
      )

      defaults = binding.assignment_defaults
      expect(defaults[:product_name]).to eq("苛性ソーダ")
      expect(defaults[:cargo_type]).to eq("液体")
      expect(defaults[:shipper_id]).to eq(shipper.id)
      expect(defaults[:origin_location_id]).to eq(origin.id)
      expect(defaults[:destination_location_id]).to eq(destination.id)
    end
  end
end
