module Admin
  class BookmarksController < ApplicationController
    before_action :set_bookmark, only: [:show, :edit, :update, :destroy]

    def index
      @bookmarks = current_tenant.bookmarks.ordered
      @bookmarks_by_category = @bookmarks.group_by(&:category)
    end

    def show
    end

    def new
      @bookmark = current_tenant.bookmarks.build
      @bookmark.shared = true
      @bookmark.icon = "link"
    end

    def create
      @bookmark = current_tenant.bookmarks.build(bookmark_params)
      @bookmark.creator = current_user

      if @bookmark.save
        redirect_to admin_bookmarks_path, notice: "ブックマークを作成しました。"
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      if @bookmark.update(bookmark_params)
        redirect_to admin_bookmarks_path, notice: "ブックマークを更新しました。"
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @bookmark.destroy
      redirect_to admin_bookmarks_path, notice: "ブックマークを削除しました。"
    end

    private

    def set_bookmark
      @bookmark = current_tenant.bookmarks.find(params[:id])
    end

    def bookmark_params
      params.require(:bookmark).permit(
        :title, :url, :description, :category, :icon, :shared, :position
      )
    end
  end
end
