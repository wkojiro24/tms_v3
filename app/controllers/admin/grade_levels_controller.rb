module Admin
  class GradeLevelsController < BaseController
    before_action :set_grade_level, only: [:edit, :update, :destroy]

    def index
      @grade_levels = current_tenant.grade_levels.order(:name)
      @grade_level = current_tenant.grade_levels.new
    end

    def create
      @grade_level = current_tenant.grade_levels.new(grade_level_params)
      if @grade_level.save
        redirect_to admin_grade_levels_path, notice: "等級を登録しました。"
      else
        @grade_levels = current_tenant.grade_levels.order(:name)
        flash.now[:alert] = "等級を登録できませんでした。"
        render :index, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      if @grade_level.update(grade_level_params)
        redirect_to admin_grade_levels_path, notice: "等級情報を更新しました。"
      else
        flash.now[:alert] = "等級情報を更新できませんでした。"
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @grade_level.destroy
      redirect_to admin_grade_levels_path, notice: "等級を削除しました。"
    end

    private

    def set_grade_level
      @grade_level = current_tenant.grade_levels.find(params[:id])
    end

    def grade_level_params
      params.require(:grade_level).permit(:code, :name, :description, :active)
    end
  end
end
