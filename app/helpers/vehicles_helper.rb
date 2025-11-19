module VehiclesHelper
  def maintenance_status_badge(status)
    case status
    when "approved"
      "success"
    when "pending", "returned"
      "warning"
    when "rejected"
      "danger"
    when "cancelled"
      "secondary"
    else
      "secondary"
    end
  end

  def fault_severity_badge(severity)
    case severity
    when "high"
      "danger"
    when "medium"
      "warning"
    else
      "secondary"
    end
  end

  def inspection_status_badge(status)
    case status
    when "completed"
      "success"
    when "overdue"
      "danger"
    else
      "warning"
    end
  end

  def fault_status_options
    [
      ["保留", "on_hold"],
      ["見積もり中", "estimating"],
      ["修理依頼済み", "repair_ordered"],
      ["その他", "other"]
    ]
  end

  def fault_status_label(status)
    option = fault_status_options.find { |label, value| value == status.to_s }
    option ? option.first : status.to_s.humanize
  end

  def inspection_scope_options
    [
      ["法定点検（車検）", "statutory"],
      ["荷主要請点検", "shipper_request"],
      ["その他", "other"]
    ]
  end

  def inspection_scope_label(scope)
    inspection_scope_options.to_h[scope.to_s] || scope.to_s.humanize
  end

  def maintenance_entry_type_label(entry_type)
    entry_type == :fault ? "故障・事象" : "車検・点検"
  end

  def maintenance_entry_status_label(entry)
    if entry[:type] == :fault
      fault_status_label(entry[:status])
    else
      entry[:record].status.humanize
    end
  end

  def maintenance_entry_status_badge(entry)
    if entry[:type] == :fault
      badge = entry[:status] == "repair_ordered" ? "warning" : "secondary"
    else
      badge = inspection_status_badge(entry[:record].status)
    end
    "text-bg-#{badge}"
  end

  def vehicle_status_options
    {
      "active" => "稼働中",
      "maintenance" => "整備中",
      "inspection" => "点検予定",
      "attention" => "要確認",
      "out_of_service" => "休車"
    }
  end

  def vehicle_status_label_from_key(key)
    vehicle_status_options[key] || "稼働中"
  end

  def vehicle_status_label(vehicle)
    vehicle_status_label_from_key(vehicle.maintenance_status)
  end

  def vehicle_status_badge_class(key)
    case key
    when "active"
      "text-bg-success"
    when "maintenance"
      "text-bg-warning"
    when "inspection"
      "text-bg-info"
    when "attention"
      "text-bg-secondary"
    when "out_of_service"
      "text-bg-danger"
    else
      "text-bg-secondary"
    end
  end

  def vehicle_metadata_value(vehicle, key)
    vehicle.metadata&.fetch(key, nil).presence
  end

  def vehicle_plate_label(vehicle)
    vehicle.registration_number.presence || vehicle.call_sign.presence || "車"
  end

  def vehicle_plate_parts(vehicle)
    text = vehicle.registration_number.to_s.strip
    match = text.match(/\A(?<region>[^\d]+)(?<class>\d+)(?<kana>[^\d]+)(?<number>.+)\z/)
    return { region: text, klass: nil, kana: nil, number: nil } if match.nil?

    {
      region: match[:region],
      klass: match[:class],
      kana: match[:kana],
      number: match[:number]
    }
  end

  def vehicle_plate_style
    "background:#0f5132;color:#fff;border-radius:0.5rem;padding:0.4rem 0.6rem;display:inline-block;text-align:center;min-width:88px;"
  end
end
