module Admin
  class DepartmentsController < BaseController
    before_action :set_department, only: [:edit, :update, :destroy]

    def index
      @departments = current_tenant.departments.order(:name)
      @department = current_tenant.departments.new
    end

    def create
      @department = current_tenant.departments.new(department_params)
      if @department.save
        redirect_to admin_departments_path, notice: "部署を登録しました。"
      else
        @departments = current_tenant.departments.order(:name)
        flash.now[:alert] = "部署を登録できませんでした。"
        render :index, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      if @department.update(department_params)
        redirect_to admin_departments_path, notice: "部署情報を更新しました。"
      else
        flash.now[:alert] = "部署情報を更新できませんでした。"
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @department.destroy
      redirect_to admin_departments_path, notice: "部署を削除しました。"
    end

    private

    def set_department
      @department = current_tenant.departments.find(params[:id])
    end

    def department_params
      params.require(:department).permit(:code, :name, :description, :active)
    end
  end
end
