module Admin
  class JobCategoriesController < BaseController
    before_action :set_job_category, only: [:edit, :update, :destroy]

    def index
      @job_categories = current_tenant.job_categories.order(:name)
      @job_category = current_tenant.job_categories.new
    end

    def create
      @job_category = current_tenant.job_categories.new(job_category_params)
      if @job_category.save
        redirect_to admin_job_categories_path, notice: "職種を登録しました。"
      else
        @job_categories = current_tenant.job_categories.order(:name)
        flash.now[:alert] = "職種を登録できませんでした。"
        render :index, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      if @job_category.update(job_category_params)
        redirect_to admin_job_categories_path, notice: "職種情報を更新しました。"
      else
        flash.now[:alert] = "職種情報を更新できませんでした。"
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @job_category.destroy
      redirect_to admin_job_categories_path, notice: "職種を削除しました。"
    end

    private

    def set_job_category
      @job_category = current_tenant.job_categories.find(params[:id])
    end

    def job_category_params
      params.require(:job_category).permit(:code, :name, :description, :active)
    end
  end
end
