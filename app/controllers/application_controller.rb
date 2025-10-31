class ApplicationController < ActionController::Base
  include CanCan::ControllerAdditions

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  rescue_from CanCan::AccessDenied do |_exception|
    redirect_to root_path, alert: "権限がありません。"
  end

  def current_ability
    @current_ability ||= Ability.new(current_user)
  end
end
