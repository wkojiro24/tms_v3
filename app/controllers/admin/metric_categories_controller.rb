module Admin
  class MetricCategoriesController < BaseController
    before_action :set_category, only: [:edit, :update, :destroy]

    def index
      @categories = MetricCategory.ordered.includes(:items)
      @category = MetricCategory.new
    end

    def create
      @category = MetricCategory.new(category_params)
      if @category.save
        redirect_to admin_metric_categories_path, notice: "カテゴリを追加しました。"
      else
        @categories = MetricCategory.ordered.includes(:items)
        flash.now[:alert] = "カテゴリを追加できませんでした。"
        render :index, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      if @category.update(category_params)
        redirect_to admin_metric_categories_path, notice: "カテゴリを更新しました。"
      else
        flash.now[:alert] = "カテゴリを更新できませんでした。"
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @category.destroy
      redirect_to admin_metric_categories_path, notice: "カテゴリを削除しました。"
    end

    private

    def set_category
      @category = MetricCategory.find(params[:id])
    end

    def category_params
      params.require(:metric_category).permit(:name, :display_label, :position)
    end
  end
end
