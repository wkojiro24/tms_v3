class VehiclesController < ApplicationController
  def index
    vehicles = Vehicle.ordered.to_a
    @query = params[:q].to_s.strip
    @vehicle_type = params[:vehicle_type].presence
    @vehicle_group = params[:group].presence
    @status_filter = params[:status].presence

    vehicles = filter_by_query(vehicles, @query)
    vehicles = vehicles.select { |vehicle| vehicle.vehicle_category == @vehicle_type } if @vehicle_type.present?
    vehicles = vehicles.select { |vehicle| vehicle.depot_name == @vehicle_group } if @vehicle_group.present?
    vehicles = vehicles.select { |vehicle| vehicle.maintenance_status == @status_filter } if @status_filter.present?

    @vehicles = vehicles
    @all_depots = Vehicle.distinct.pluck(:depot_name).compact_blank
    @vehicle_types = Vehicle.distinct.pluck(:vehicle_category).compact_blank
    @status_counts = build_status_counts(Vehicle.ordered.to_a)
  end

  def show
    @vehicle = Vehicle.find_by(id: params[:id]) ||
               Vehicle.find_by!(call_sign: params[:id]) ||
               Vehicle.find_by!(registration_number: params[:id])
    @vehicle_financial_code = @vehicle.call_sign.presence || @vehicle.registration_number
    @maintenance_overview = VehicleMaintenanceOverview.new(vehicle: @vehicle)
    @repair_requests = @maintenance_overview.repair_requests(limit: 5)
    @fault_logs = @maintenance_overview.fault_logs(limit: nil)
    @inspection_records = @maintenance_overview.inspection_records
    @inspection_events = @maintenance_overview.inspection_schedule_events
    @maintenance_entries = build_maintenance_entries
    @selected_photo = selected_vehicle_photo
    @new_fault_log = @vehicle.vehicle_fault_logs.build(occurred_on: Date.current)
    @new_inspection_record = @vehicle.vehicle_inspection_records.build(
      scheduled_on: Date.current.next_month.beginning_of_month,
      inspection_type: "車検",
      inspection_scope: "statutory"
    )
  end

  def update
    @vehicle = Vehicle.find(params[:id])
    if @vehicle.update(vehicle_params)
      redirect_to vehicle_path(@vehicle), notice: "車両情報を更新しました。"
    else
      redirect_to vehicle_path(@vehicle), alert: @vehicle.errors.full_messages.to_sentence
    end
  end

  def schedule
    @start_month = parse_month(params[:start_month]) || Date.current.beginning_of_month
    @schedule_depot = params[:depot].presence
    @schedule_type  = params[:vehicle_type].presence

    scope = Vehicle.ordered
    scope = scope.where(depot_name: @schedule_depot) if @schedule_depot.present? && @schedule_depot != "all"
    scope = scope.where(vehicle_category: @schedule_type) if @schedule_type.present?
    @vehicles = scope.to_a

    # セレクトボックス用
    @all_depots    = Vehicle.distinct.pluck(:depot_name).compact_blank
    @vehicle_types = Vehicle.distinct.pluck(:vehicle_category).compact_blank

    # groups（左側：車両）
    number_to_group = {}
    @timeline_groups = @vehicles.map do |vehicle|
      raw_number = vehicle.registration_number.to_s.presence ||
                   vehicle.call_sign.to_s.presence ||
                   vehicle.id.to_s
      group_id = vehicle.id.to_s

      plate_parts = view_context.vehicle_plate_parts(vehicle)
      content_html = <<~HTML.squish
        <div class="plate-mini">
          <div class="plate-mini__line1">#{ERB::Util.h(plate_parts[:region])} #{ERB::Util.h(plate_parts[:klass])}</div>
          <div class="plate-mini__line2">#{ERB::Util.h(plate_parts[:kana])} #{ERB::Util.h(plate_parts[:number])}</div>
        </div>
      HTML

      number_to_group[raw_number] ||= group_id

      {
        id: group_id,
        number: raw_number,
        content: content_html.html_safe,
        office: vehicle.depot_name.to_s,
        vehicle_type: vehicle.vehicle_category.to_s
      }
    end

    # メンテナンス種別
    categories = MaintenanceCategory.order(:key).index_by(&:key)
    @maintenance_categories = categories.values

    # items（MaintenanceEvent）
    @timeline_items = MaintenanceEvent.all.map do |event|
      cat = categories[event.category]
      group_id = number_to_group[event.vehicle_number.to_s] || event.vehicle_number.to_s

      {
        id: "event-#{event.id}",
        db_id: event.id,
        group: group_id,
        start: event.start_at&.iso8601,
        end: event.end_at&.iso8601,
        content: label_for_event(event, cat),
        type: "range",
        # 色は MaintenanceCategory.key にひも付くクラスで制御
        className: (cat.present? ? "item-#{cat.key.to_s.parameterize}" : css_class_for_event(event, cat)),
        category_key: event.category
      }
    end
  end

  def timeline_demo
    @demo_start = Time.zone.now.beginning_of_day
    @demo_end = @demo_start + 12.hours
    @demo_groups = [
      { id: 0, content: "Truck 0" },
      { id: 1, content: "Truck 1" },
      { id: 2, content: "Truck 2" }
    ]
    @demo_items = [
      {
        id: "seed-0",
        group: 0,
        start: @demo_start.iso8601,
        end: (@demo_start + 4.hours).iso8601,
        content: "Order 0"
      },
      {
        id: "seed-1",
        group: 1,
        start: (@demo_start + 2.hours).iso8601,
        end: (@demo_start + 6.hours).iso8601,
        content: "Order 1"
      },
      {
        id: "seed-2",
        group: 2,
        start: (@demo_start + 3.hours).iso8601,
        end: (@demo_start + 5.hours).iso8601,
        content: "Order 2"
      }
    ]

    render layout: "timeline_demo"
  end

  private

  def vehicle_params
    params.require(:vehicle).permit(
      :depot_name,
      :registration_number,
      :call_sign,
      :first_registration_on,
      :model_code,
      :manufacturer_name,
      :vehicle_category,
      :shipper_name,
      :cargo_name,
      :tank_material,
      :notes
    )
  end

  def selected_vehicle_photo
    return if @vehicle.photos.blank?

    selected_id = params[:photo_id]
    if selected_id.present?
      @vehicle.photos.find_by(id: selected_id) || @vehicle.photos.first
    else
      @vehicle.photos.first
    end
  end

  def build_maintenance_entries
    entries = []
    @fault_logs.each do |fault|
      entries << {
        type: :fault,
        occurred_on: fault.occurred_on,
        status: fault.status,
        title: fault.title,
        detail: fault.description,
        record: fault
      }
    end
    @inspection_records.each do |inspection|
      entries << {
        type: :inspection,
        occurred_on: inspection.scheduled_on || inspection.completed_on,
        status: inspection.status,
        title: inspection.inspection_type,
        detail: inspection.notes,
        record: inspection
      }
    end

    entries.compact.sort_by { |entry| entry[:occurred_on] || Date.new(1900) }.reverse
  end

  def label_for_event(event, category = nil)
    return category.name if category&.name.present?

    case event.category
    when "shaken" then "車検"
    when "tenken" then "点検"
    when "shuuri" then "修理"
    when "tire"   then "タイヤ交換"
    else
      event.category
    end
  end

  def css_class_for_event(event, category = nil)
    key = category&.key || event.category
    return "" if key.blank?

    "item-#{key.parameterize}"
  end

  def filter_by_query(vehicles, query)
    return vehicles if query.blank?

    normalized = query.downcase
    vehicles.select do |vehicle|
      [
        vehicle.registration_number,
        vehicle.call_sign,
        vehicle.manufacturer_name,
        vehicle.model_code,
        vehicle.metadata&.dig("vin")
      ].compact.any? { |value| value.downcase.include?(normalized) }
    end
  end

  def build_status_counts(all_vehicles)
    counts = Hash.new(0)
    all_vehicles.each do |vehicle|
      counts[vehicle.maintenance_status] += 1
    end
    counts
  end

  def parse_date(value)
    return if value.blank?

    Date.parse(value.to_s)
  rescue ArgumentError
    nil
  end

  def parse_month(value)
    return if value.blank?

    Date.strptime(value, "%Y-%m").beginning_of_month
  rescue ArgumentError
    nil
  end
end
