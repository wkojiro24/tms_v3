module BookmarksHelper
  def bookmark_category_color(category)
    case category
    when "general"
      "secondary"
    when "system"
      "primary"
    when "reference"
      "info"
    when "government"
      "success"
    when "partner"
      "warning"
    when "internal"
      "dark"
    else
      "secondary"
    end
  end
end
