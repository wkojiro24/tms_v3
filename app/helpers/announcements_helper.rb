module AnnouncementsHelper
  def category_badge_color(category)
    case category
    when "general"
      "secondary"
    when "system"
      "info"
    when "hr"
      "primary"
    when "safety"
      "danger"
    when "operation"
      "success"
    when "event"
      "warning"
    when "training"
      "purple"
    when "maintenance"
      "dark"
    else
      "secondary"
    end
  end
end
