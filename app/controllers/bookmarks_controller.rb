class BookmarksController < ApplicationController
  before_action :set_bookmark, only: [:edit, :update, :destroy]

  def index
    @shared_bookmarks = current_tenant.bookmarks.shared.ordered
    @shared_by_category = @shared_bookmarks.group_by(&:category)

    @personal_bookmarks = current_tenant.bookmarks.personal_for(current_user).ordered
    @personal_by_category = @personal_bookmarks.group_by(&:category)
  end

  def new
    @bookmark = current_tenant.bookmarks.build
    @bookmark.shared = false
    @bookmark.icon = "link"
  end

  def create
    @bookmark = current_tenant.bookmarks.build(bookmark_params)
    @bookmark.creator = current_user
    @bookmark.shared = false # 一般ユーザーは個人ブックマークのみ

    if @bookmark.save
      redirect_to bookmarks_path, notice: "ブックマークを作成しました。"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @bookmark.update(bookmark_params.merge(shared: false))
      redirect_to bookmarks_path, notice: "ブックマークを更新しました。"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @bookmark.destroy
    redirect_to bookmarks_path, notice: "ブックマークを削除しました。"
  end

  private

  def set_bookmark
    @bookmark = current_tenant.bookmarks.personal_for(current_user).find(params[:id])
  end

  def bookmark_params
    params.require(:bookmark).permit(:title, :url, :description, :category, :icon, :position)
  end
end
