module Admin
  class EvaluationGradesController < BaseController
    before_action :set_evaluation_grade, only: [:edit, :update, :destroy]

    def index
      @evaluation_grades = current_tenant.evaluation_grades.order(:score, :name)
      @evaluation_grade = current_tenant.evaluation_grades.new
    end

    def create
      @evaluation_grade = current_tenant.evaluation_grades.new(evaluation_grade_params)
      if @evaluation_grade.save
        redirect_to admin_evaluation_grades_path, notice: "評価ランクを登録しました。"
      else
        @evaluation_grades = current_tenant.evaluation_grades.order(:score, :name)
        flash.now[:alert] = "評価ランクを登録できませんでした。"
        render :index, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      if @evaluation_grade.update(evaluation_grade_params)
        redirect_to admin_evaluation_grades_path, notice: "評価ランクを更新しました。"
      else
        flash.now[:alert] = "評価ランクを更新できませんでした。"
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @evaluation_grade.destroy
      redirect_to admin_evaluation_grades_path, notice: "評価ランクを削除しました。"
    end

    private

    def set_evaluation_grade
      @evaluation_grade = current_tenant.evaluation_grades.find(params[:id])
    end

    def evaluation_grade_params
      params.require(:evaluation_grade).permit(:code, :name, :band, :score, :active)
    end
  end
end
