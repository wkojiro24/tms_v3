class MaintenanceCategoriesController < ApplicationController
  before_action :set_category, only: [:edit, :update, :destroy]

  def index
    @categories = MaintenanceCategory.order(:key)
    @category = MaintenanceCategory.new
  end

  def create
    @category = MaintenanceCategory.new(category_params)
    if @category.save
      redirect_to maintenance_categories_path, notice: "種別を追加しました。"
    else
      @categories = MaintenanceCategory.order(:key)
      flash.now[:alert] = @category.errors.full_messages.to_sentence
      render :index, status: :unprocessable_entity
    end
  end

  def edit
    @categories = MaintenanceCategory.order(:key)
    render :index
  end

  def update
    if @category.update(category_params)
      redirect_to maintenance_categories_path, notice: "種別を更新しました。"
    else
      @categories = MaintenanceCategory.order(:key)
      flash.now[:alert] = @category.errors.full_messages.to_sentence
      render :index, status: :unprocessable_entity
    end
  end

  def destroy
    @category.destroy
    redirect_to maintenance_categories_path, notice: "種別を削除しました。"
  end

  private

  def set_category
    @category = MaintenanceCategory.find(params[:id])
  end

  def category_params
    params.require(:maintenance_category).permit(:key, :name, :color)
  end
end
