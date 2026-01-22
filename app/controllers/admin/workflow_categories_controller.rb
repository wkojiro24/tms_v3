module Admin
  class WorkflowCategoriesController < BaseController
    before_action :set_category, only: [:show, :edit, :update, :destroy]

    def index
      @workflow_categories = WorkflowCategory.includes(:stage_templates, :notifications).order(:name)
    end

    def show
    end

    def new
      @workflow_category = WorkflowCategory.new
    end

    def edit
    end

    def create
      @workflow_category = WorkflowCategory.new(category_params)
      if @workflow_category.save
        redirect_to admin_workflow_category_path(@workflow_category), notice: "カテゴリを作成しました。"
      else
        flash.now[:alert] = "カテゴリを作成できませんでした。"
        render :new, status: :unprocessable_entity
      end
    end

    def update
      if @workflow_category.update(category_params)
        redirect_to admin_workflow_category_path(@workflow_category), notice: "カテゴリを更新しました。"
      else
        flash.now[:alert] = "カテゴリを更新できませんでした。"
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @workflow_category.destroy
      redirect_to admin_workflow_categories_path, notice: "カテゴリを削除しました。"
    rescue ActiveRecord::DeleteRestrictionError => e
      redirect_to admin_workflow_category_path(@workflow_category), alert: e.message
    end

    private

    def set_category
      @workflow_category = WorkflowCategory.find(params[:id])
    end

    def category_params
      params.require(:workflow_category).permit(:name, :code, :description, :active)
    end
  end
end
