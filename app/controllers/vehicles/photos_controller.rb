module Vehicles
  class PhotosController < ApplicationController
    before_action :set_vehicle

    def create
      uploads = Array.wrap(photo_params[:photos]).compact_blank
      if uploads.blank?
        redirect_to vehicle_path(@vehicle, anchor: "gallery"), alert: "画像ファイルを選択してください。"
        return
      end

      remaining_slots = 20 - @vehicle.photos.attachments.size
      if uploads.size > remaining_slots
        redirect_to vehicle_path(@vehicle, anchor: "gallery"), alert: "写真は最大20枚までです。残り#{remaining_slots}枚まで追加できます。"
        return
      end

      @vehicle.photos.attach(uploads)
      redirect_to vehicle_path(@vehicle, anchor: "gallery"), notice: "#{uploads.size}枚の写真を追加しました。"
    end

    def destroy
      photo = @vehicle.photos.attachments.find(params[:id])
      photo.purge
      redirect_to vehicle_path(@vehicle, anchor: "gallery"), notice: "写真を削除しました。"
    end

    private

    def set_vehicle
      @vehicle = Vehicle.find(params[:vehicle_id])
    end

    def photo_params
      params.permit(photos: [])
    end
  end
end
