module Admin
  class AnnouncementsController < ApplicationController
    before_action :set_announcement, only: [:show, :edit, :update, :destroy]

    def index
      @announcements = current_tenant.announcements
        .order(pinned: :desc, published_at: :desc)
    end

    def show
    end

    def new
      @announcement = current_tenant.announcements.build
      @announcement.published_at = Time.current
    end

    def create
      @announcement = current_tenant.announcements.build(announcement_params)
      @announcement.author = current_user

      if @announcement.save
        redirect_to admin_announcements_path, notice: "お知らせを作成しました。"
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      if @announcement.update(announcement_params)
        redirect_to admin_announcements_path, notice: "お知らせを更新しました。"
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @announcement.destroy
      redirect_to admin_announcements_path, notice: "お知らせを削除しました。"
    end

    private

    def set_announcement
      @announcement = current_tenant.announcements.find(params[:id])
    end

    def announcement_params
      params.require(:announcement).permit(
        :title, :body, :category, :published_at, :expires_at, :pinned,
        :event_date, :event_end_date, :event_location, :all_day
      )
    end
  end
end
