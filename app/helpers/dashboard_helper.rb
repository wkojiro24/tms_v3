module DashboardHelper
  def workflow_status_color(status)
    case status
    when "pending", "draft"
      "secondary"
    when "submitted"
      "primary"
    when "in_review"
      "info"
    when "approved"
      "success"
    when "rejected"
      "danger"
    when "cancelled"
      "dark"
    else
      "secondary"
    end
  end

  def workflow_status_label(status)
    case status
    when "pending"
      "下書き"
    when "draft"
      "下書き"
    when "submitted"
      "申請中"
    when "in_review"
      "審査中"
    when "approved"
      "承認済"
    when "rejected"
      "却下"
    when "cancelled"
      "取消"
    else
      status
    end
  end
end
