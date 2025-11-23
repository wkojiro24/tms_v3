module WorkflowRequestsHelper
  def workflow_status_badge(request)
    classes = case request.status
    when "approved" then "badge bg-success"
    when "pending" then "badge bg-primary"
    when "returned" then "badge bg-warning text-dark"
    when "rejected" then "badge bg-danger"
              else
                "badge bg-secondary"
    end
    content_tag(:span, request.human_status, class: classes)
  end

  def previewable_blob?(blob)
    return false unless blob.respond_to?(:content_type)

    type = blob.content_type
    type.start_with?("image/") || type == "application/pdf"
  end

  def metadata_input_value(request, key)
    value = request.public_send(key)
    return "" if value.blank?

    case WorkflowRequest::METADATA_FIELDS[key][:type]
    when :date
      begin
        Date.parse(value.to_s).strftime("%Y-%m-%d")
      rescue ArgumentError
        value
      end
    when :datetime
      begin
        Time.zone.parse(value.to_s).strftime("%Y-%m-%dT%H:%M")
      rescue ArgumentError
        value
      end
    else
      value
    end
  end
end
