class AnnouncementsController < ApplicationController
  def index
    @announcements = current_tenant.announcements
      .published
      .pinned_first

    # 今後のイベント
    @upcoming_events = current_tenant.announcements
      .published
      .upcoming_events
      .limit(5)
  end

  def show
    @announcement = current_tenant.announcements.find(params[:id])
  end
end
